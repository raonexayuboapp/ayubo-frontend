import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/benefit_line.dart';
import '../widgets/loading_button.dart';

String _euros(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// One editable benefit: a shopping credit, a discount, or a perk (text only).
/// The kind is chosen when the benefit is added and never changes: to change it, remove it and add a new one.
class _BenefitRow {
  final String kind; // credit | discount | perk
  final String? code; // set for a benefit that already exists on the server
  final TextEditingController amount; // euros (credit) or percent (discount); unused for a perk
  final TextEditingController description;
  bool descriptionTouched; // once the admin words the line themselves, it is no longer filled in automatically

  _BenefitRow({
    required this.kind,
    this.code,
    String initialAmount = '',
    String initialDescription = '',
    bool touched = false,
  })  : amount = TextEditingController(text: initialAmount),
        description = TextEditingController(text: initialDescription),
        descriptionTouched = touched {
    amount.addListener(_suggest);
  }

  factory _BenefitRow.fromJson(Map<String, dynamic> b) {
    final kind = b['kind'] as String;
    var amount = '';
    if (kind == 'credit') {
      amount = _euros(b['credit_cents'] as int);
    } else if (kind == 'discount') {
      amount = formatPercent(b['discount_percent'] as num);
    }

    return _BenefitRow(
      kind: kind,
      code: b['code'] as String,
      initialAmount: amount,
      initialDescription: b['description'] as String,
      touched: true,
    );
  }

  /// The line suggested for the amount typed in, or '' when there is nothing sensible to suggest.
  String suggestion() {
    if (kind == 'credit') {
      final cents = parseEuroToCents(amount.text);
      return cents == null || cents < 1 ? '' : '${formatCents(cents)} shopping credit';
    }
    if (kind == 'discount') {
      final n = double.tryParse(amount.text.trim().replaceAll(',', '.'));
      return n == null || n <= 0 || n > 100 ? '' : '${formatPercent(n)}% discount on all products';
    }
    return '';
  }

  void _suggest() {
    if (descriptionTouched) return;
    final s = suggestion();
    if (s.isNotEmpty) description.text = s;
  }

  void dispose() {
    amount.dispose();
    description.dispose();
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
  static const _maxBenefits = 20;

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

  bool _has(String kind) => _benefits.any((b) => b.kind == kind);

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
        _price.text = _originalPriceCents == null ? '' : _euros(_originalPriceCents!);
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
    if (cents == null) return 'Enter an amount like 200 or 49.90.';
    return cents > _maxCents ? 'The price is too high.' : null;
  }

  String? _vAmount(_BenefitRow row, String? v) {
    final s = (v ?? '').trim().replaceAll(',', '.');

    if (row.kind == 'credit') {
      final cents = parseEuroToCents(s);
      if (cents == null || cents < 1) return 'Enter an amount like 200 or 49.90.';
      return cents > _maxCents ? 'The amount is too high.' : null;
    }

    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(s)) return 'A number such as 10 or 7.5.';
    final n = double.parse(s);
    return n > 0 && n <= 100 ? null : 'More than 0 and at most 100.';
  }

  String? _vBenefitDescription(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 300 ? 'Description must be 1 to 300 characters.' : null;
  }

  // ---------- benefits ----------

  void _addBenefit(String kind) => setState(() => _benefits.add(_BenefitRow(kind: kind)));

  void _removeBenefit(int i) {
    final row = _benefits[i];
    setState(() => _benefits.removeAt(i));
    // Dispose after the frame: the removed fields are still on screen until it finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _benefits.length) return;

    setState(() {
      final row = _benefits.removeAt(i);
      _benefits.insert(j, row);
    });
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
      // The whole list, in display order. An existing benefit sends its code back, which is how the server
      // keeps anything another system stored in it.
      'benefits': [
        for (final b in _benefits)
          {
            'kind': b.kind,
            if (b.code != null) 'code': b.code,
            'description': b.description.text.trim(),
            if (b.kind == 'credit') 'credit_cents': parseEuroToCents(b.amount.text)!,
            if (b.kind == 'discount') 'discount_percent': b.amount.text.trim().replaceAll(',', '.'), // text keeps it exact
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
    final theme = Theme.of(context);
    String? server(String f) => _serverErrors['benefits.$i.$f'];

    final label = switch (b.kind) {
      'credit' => 'Shopping credit',
      'discount' => 'Discount',
      _ => 'Perk (text only)',
    };

    return Card(
      key: ObjectKey(b),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Icon(benefitIcon(b.kind), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            IconButton(
              tooltip: 'Move up',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: i == 0 ? null : () => _move(i, -1),
            ),
            IconButton(
              tooltip: 'Move down',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_downward, size: 20),
              onPressed: i == _benefits.length - 1 ? null : () => _move(i, 1),
            ),
            IconButton(
              tooltip: 'Remove benefit',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeBenefit(i),
            ),
          ]),
          if (server('kind') != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(server('kind')!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (b.kind != 'perk') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: b.amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => _vAmount(b, v),
              forceErrorText: server(b.kind == 'credit' ? 'credit_cents' : 'discount_percent'),
              decoration: InputDecoration(labelText: b.kind == 'credit' ? 'Credit amount (€)' : 'Discount (%)'),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: b.description,
            minLines: 1,
            maxLines: 2,
            maxLength: 300,
            onChanged: (_) => b.descriptionTouched = true, // the admin worded it: stop suggesting
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vBenefitDescription,
            forceErrorText: server('description'),
            decoration: InputDecoration(
              labelText: 'Line shown to customers',
              helperText: b.kind == 'perk' ? 'e.g. Access to exclusive offers' : 'Filled in from the amount, you can reword it.',
              helperMaxLines: 2,
            ),
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
    final full = _benefits.length >= _maxBenefits;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit plan' : 'New plan')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text('code', 'Code', _code, _vCode,
                enabled: !_editing, helper: _editing ? 'The code cannot be changed.' : 'e.g. entry or gold'),
            _text('name', 'Name', _name, _vName, helper: 'e.g. Entry Membership'),
            _text('description', 'Short description (shown under the name)', _desc, _vDesc,
                maxLines: 2, helper: 'e.g. Perfect for getting to know each other'),
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
                    DropdownMenuItem<int>(
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
              'What a member gets, in the order customers read it. Use the arrows to reorder. '
                  'A plan can have one shopping credit and one discount, plus any number of perks.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _benefits.length; i++) _benefitCard(i),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: full || _has('credit') ? null : () => _addBenefit('credit'),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Shopping credit'),
              ),
              OutlinedButton.icon(
                onPressed: full || _has('discount') ? null : () => _addBenefit('discount'),
                icon: const Icon(Icons.sell_outlined),
                label: const Text('Discount'),
              ),
              OutlinedButton.icon(
                onPressed: full ? null : () => _addBenefit('perk'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Perk'),
              ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 24),
            LoadingButton(label: _editing ? 'Save changes' : 'Create plan', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}