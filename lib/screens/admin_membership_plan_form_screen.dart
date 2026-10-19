import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/loading_button.dart';

/// One editable benefit. Existing benefits keep their code (it is their identity on the server).
class _BenefitRow {
  final bool isNew;
  final TextEditingController code;
  final TextEditingController description;
  final TextEditingController percent;

  _BenefitRow({this.isNew = true, String code = '', String description = '', String percent = ''})
      : code = TextEditingController(text: code),
        description = TextEditingController(text: description),
        percent = TextEditingController(text: percent);

  factory _BenefitRow.fromJson(Map<String, dynamic> b) {
    final d = b['discount_percent'] as num?;
    return _BenefitRow(
      isNew: false,
      code: b['code'] as String,
      description: b['description'] as String,
      percent: d == null ? '' : formatPercent(d),
    );
  }

  void dispose() {
    code.dispose();
    description.dispose();
    percent.dispose();
  }
}

class AdminMembershipPlanFormScreen extends StatefulWidget {
  final int? planId; // null = create, otherwise edit
  const AdminMembershipPlanFormScreen({super.key, this.planId});

  @override
  State<AdminMembershipPlanFormScreen> createState() => _AdminMembershipPlanFormScreenState();
}

class _AdminMembershipPlanFormScreenState extends State<AdminMembershipPlanFormScreen> {
  static const _maxCents = 100000000; // the server's limit: 1,000,000.00

  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();

  bool _active = true;
  bool _hasProduct = true; // false: a plan made elsewhere that has no product yet
  int? _taxRateId;
  int? _originalTaxRateId;
  int? _originalPriceCents;
  List<Map<String, dynamic>> _taxRates = [];
  final List<_BenefitRow> _benefits = [];

  bool _loadingData = true;
  String? _loadError;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.planId != null;

  /// A price is mandatory when creating, and when the plan already has a product.
  bool get _priceRequired => !_editing || _hasProduct;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _desc, _price]) {
      c.dispose();
    }
    for (final b in _benefits) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final api = ApiService.instance;
      final results = await Future.wait<Object>([
        api.adminTaxRates(),
        if (_editing) api.adminMembershipPlan(widget.planId!),
      ]);
      if (!mounted) return;

      final taxRates = [...(results[0] as List<Map<String, dynamic>>)];

      if (_editing) {
        final p = results[1] as Map<String, dynamic>;

        _code.text = p['code'] as String;
        _name.text = p['name'] as String;
        _desc.text = (p['description'] as String?) ?? '';
        _active = p['active'] == true;
        _hasProduct = p['has_product'] == true;
        _originalPriceCents = p['price_cents'] as int?;
        _price.text = _originalPriceCents == null
            ? ''
            : '${_originalPriceCents! ~/ 100}.${(_originalPriceCents! % 100).toString().padLeft(2, '0')}';
        _taxRateId = p['tax_rate_id'] as int?;
        _originalTaxRateId = _taxRateId;
        _benefits.addAll((p['benefits'] as List<dynamic>).cast<Map<String, dynamic>>().map(_BenefitRow.fromJson));

        // The plan's own rate may have ended. Keep it in the list so the dropdown stays valid;
        // it is only sent to the server if the admin picks a different one.
        if (_taxRateId != null && !taxRates.any((t) => t['id'] == _taxRateId)) {
          taxRates.add({
            'id': _taxRateId,
            'code': p['tax_rate_code'],
            'rate_percent': p['tax_rate_percent'],
            'ended': true,
          });
        }
      } else if (taxRates.isNotEmpty) {
        _taxRateId = taxRates.first['id'] as int;
      }

      setState(() {
        _taxRates = taxRates;
        _loadingData = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingData = false;
      });
    }
  }

  // ---------- validation (the server checks everything again) ----------

  String? _vCode(String? v) {
    final s = (v ?? '').trim();
    return s.length <= 40 && RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(s)
        ? null
        : 'Lowercase letters and numbers separated by single hyphens (maximum 40).';
  }

  String? _vName(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 100 ? 'Name must be 1 to 100 characters.' : null;
  }

  String? _vDesc(String? v) => (v ?? '').trim().length > 2000 ? 'Maximum 2000 characters.' : null;

  String? _vPrice(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return _priceRequired ? 'Enter a price.' : null;

    final cents = parseEuroToCents(s);
    if (cents == null) return 'Enter an amount like 49 or 49.90.';
    return cents > _maxCents ? 'The price is too high.' : null;
  }

  String? _vBenefitCode(_BenefitRow row, String? v) {
    final s = (v ?? '').trim();
    if (!RegExp(r'^[a-z][a-z0-9_]{1,49}$').hasMatch(s)) {
      return '2 to 50 characters: lowercase letters, numbers and _.';
    }
    return _benefits.where((b) => b.code.text.trim() == s).length > 1 ? 'This code is used twice.' : null;
  }

  String? _vBenefitDescription(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 1000 ? 'Description must be 1 to 1000 characters.' : null;
  }

  String? _vPercent(String? v) {
    final s = (v ?? '').trim().replaceAll(',', '.');
    if (s.isEmpty) return null; // a benefit without a discount is fine
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(s)) return 'A number such as 5 or 7.5.';
    final n = double.parse(s);
    return n > 0 && n <= 100 ? null : 'More than 0 and at most 100.';
  }

  // ---------- benefits ----------

  void _addBenefit() => setState(() => _benefits.add(_BenefitRow()));

  void _removeBenefit(int i) {
    final row = _benefits[i];
    setState(() => _benefits.removeAt(i));
    // Dispose after the frame: the removed fields are still on screen until it finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  // ---------- save ----------

  bool _isFieldKey(String k) =>
      const {'code', 'name', 'description', 'price_cents', 'tax_rate_id'}.contains(k) ||
          RegExp(r'^benefits\.\d+\.').hasMatch(k);

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    final priceText = _price.text.trim();
    // Price and tax rate are only sent when they changed, so a stale form cannot overwrite another admin's edit
    // and a plan whose tax rate has ended can still be renamed.
    final sendPrice = priceText.isNotEmpty && (!_editing || parseEuroToCents(priceText) != _originalPriceCents);
    final sendTax = !_editing || (_hasProduct ? _taxRateId != _originalTaxRateId : sendPrice);

    final body = <String, dynamic>{
      if (!_editing) 'code': _code.text.trim(),
      'name': _name.text.trim(),
      'description': orNull(_desc.text),
      'active': _active,
      if (sendPrice) 'price_cents': parseEuroToCents(priceText)!, // safe: validate() accepted it
      if (sendTax) 'tax_rate_id': _taxRateId,
      'benefits': [
        for (final b in _benefits)
          {
            'code': b.code.text.trim(),
            'description': b.description.text.trim(),
            // Sent as text so the percentage stays exact.
            'discount_percent': b.percent.text.trim().isEmpty ? null : b.percent.text.trim().replaceAll(',', '.'),
          },
      ],
    };

    try {
      if (_editing) {
        await ApiService.instance.adminUpdateMembershipPlan(widget.planId!, body);
      } else {
        await ApiService.instance.adminCreateMembershipPlan(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errs = e.fieldErrors;
      final general = errs.entries.where((x) => !_isFieldKey(x.key)).map((x) => x.value).join('\n');
      setState(() {
        _serverErrors = errs;
        _error = errs.isEmpty ? e.message : (general.isEmpty ? null : general);
        _saving = false;
      });
    }
  }

  // ---------- UI ----------

  Widget _text(
      String serverKey,
      String label,
      TextEditingController c,
      String? Function(String?) validator, {
        int maxLines = 1,
        TextInputType? type,
        String? helper,
        bool enabled = true,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: type,
        textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3),
      ),
    );
  }

  Widget _benefitCard(int i) {
    final b = _benefits[i];
    String? server(String f) => _serverErrors['benefits.$i.$f'];

    return Card(
      key: ObjectKey(b),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: b.code,
                enabled: b.isNew, // the code identifies the benefit: only a new one can choose it
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => _vBenefitCode(b, v),
                forceErrorText: server('code'),
                decoration: InputDecoration(labelText: 'Code', helperText: b.isNew ? 'e.g. member_discount' : null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: b.percent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vPercent,
                forceErrorText: server('discount_percent'),
                decoration: const InputDecoration(labelText: 'Discount %', helperText: 'optional'),
              ),
            ),
            IconButton(
              tooltip: 'Remove benefit',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeBenefit(i),
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: b.description,
            maxLines: 2,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vBenefitDescription,
            forceErrorText: server('description'),
            decoration: const InputDecoration(labelText: 'Description (shown to customers)'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingData) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!),
            TextButton(
              onPressed: () {
                setState(() {
                  _loadingData = true;
                  _loadError = null;
                });
                _init();
              },
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }

    final endedRateSelected = _taxRates.any((t) => t['id'] == _taxRateId && t['ended'] == true);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit plan' : 'New plan')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text('code', 'Code', _code, _vCode,
                enabled: !_editing, helper: _editing ? 'The code cannot be changed.' : 'e.g. family or gold'),
            _text('name', 'Name', _name, _vName),
            _text('description', 'Description (optional)', _desc, _vDesc, maxLines: 3),
            if (_editing && !_hasProduct)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'This plan has no product yet, so it cannot be bought. Set a price and a tax rate to put it on sale.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            _text('price_cents', 'Price (€, incl. VAT)', _price, _vPrice,
                type: const TextInputType.numberWithOptions(decimal: true)),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<int>(
                value: _taxRateId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Tax rate',
                  helperText: _taxRates.isEmpty
                      ? 'No tax rate exists yet. Create one under Admin, Tax rates.'
                      : endedRateSelected
                      ? 'This rate has ended. It still works for this plan, but a current rate should replace it.'
                      : null,
                  helperMaxLines: 3,
                  errorText: _serverErrors['tax_rate_id'],
                ),
                validator: (v) => v == null && _priceRequired ? 'Choose a tax rate.' : null,
                items: [
                  for (final t in _taxRates)
                    DropdownMenuItem(
                      value: t['id'] as int,
                      child: Text('${t['code']} (${t['rate_percent']}%)${t['ended'] == true ? ' · ended' : ''}'),
                    ),
                ],
                onChanged: (v) => setState(() => _taxRateId = v),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available to buy'),
              subtitle: const Text('Turning this off hides the plan. Existing members keep their membership.'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const Divider(height: 32),
            Text('Benefits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'What members get. A benefit with a discount shows "x% off" to customers.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _benefits.length; i++) _benefitCard(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _benefits.length >= 20 ? null : _addBenefit,
                icon: const Icon(Icons.add),
                label: const Text('Add benefit'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            LoadingButton(label: _editing ? 'Save changes' : 'Create plan', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}