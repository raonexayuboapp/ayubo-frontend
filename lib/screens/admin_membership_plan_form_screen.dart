import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/benefit_line.dart';
import '../widgets/loading_button.dart';

typedef PlanData = Map<String, dynamic>;

String _euros(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// One editable benefit: a shopping credit, a discount, or a perk (text only).
class _BenefitRow {
  final String kind; // credit | discount | perk
  final String? code; // set for a benefit that already exists on the server
  final TextEditingController amount; // euros (credit) or percent (discount)
  final TextEditingController description;
  bool descriptionTouched;

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

  factory _BenefitRow.fromJson(PlanData b) {
    final kind = b['kind'] as String;
    var amount = '';
    if (kind == 'credit') {
      amount = _euros(b['credit_cents'] as int);
    } else if (kind == 'discount') {
      amount = formatPercent(b['discount_percent'] as num);
    }

    return _BenefitRow(
      kind: kind,
      code: b['code'] as String?,
      initialAmount: amount,
      initialDescription: (b['description'] as String?) ?? '',
      touched: true,
    );
  }

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
  static const _maxCents = 100000000; // 1,000,000.00
  static const _maxBenefits = 20;

  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();

  bool _active = true;
  bool _hasProduct = true;
  int? _taxRateId;
  int? _originalTaxRateId;
  int? _originalPriceCents;
  List<PlanData> _taxRates = [];
  final List<_BenefitRow> _benefits = [];

  bool _loadingData = true;
  String? _loadError;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.planId != null;

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

      final taxRates = (results[0] as List<dynamic>).cast<PlanData>();

      if (_editing) {
        final p = results[1] as PlanData;

        _code.text = p['code'] as String;
        _name.text = p['name'] as String;
        _desc.text = (p['description'] as String?) ?? '';
        _active = p['active'] == true;
        _hasProduct = p['has_product'] == true;
        _originalPriceCents = p['price_cents'] as int?;
        _price.text = _originalPriceCents == null ? '' : _euros(_originalPriceCents!);
        _taxRateId = p['tax_rate_id'] as int?;
        _originalTaxRateId = _taxRateId;
        _benefits.addAll(
          (p['benefits'] as List<dynamic>).cast<PlanData>().map(_BenefitRow.fromJson),
        );

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

  // ---------- validation ----------

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
    final sendPrice = priceText.isNotEmpty && (!_editing || parseEuroToCents(priceText) != _originalPriceCents);
    final sendTax = !_editing || (_hasProduct ? _taxRateId != _originalTaxRateId : sendPrice);

    final body = <String, dynamic>{
      if (!_editing) 'code': _code.text.trim(),
      'name': _name.text.trim(),
      'description': orNull(_desc.text),
      'active': _active,
      if (sendPrice) 'price_cents': parseEuroToCents(priceText)!,
      if (sendTax) 'tax_rate_id': _taxRateId,
      'benefits': [
        for (final b in _benefits)
          {
            'kind': b.kind,
            if (b.code != null) 'code': b.code,
            'description': b.description.text.trim(),
            if (b.kind == 'credit') 'credit_cents': parseEuroToCents(b.amount.text)!,
            if (b.kind == 'discount') 'discount_percent': b.amount.text.trim().replaceAll(',', '.'),
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
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
        ),
      ),
    );
  }

  Widget _benefitCard(int i) {
    final b = _benefits[i];
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    String? server(String f) => _serverErrors['benefits.$i.$f'];

    final label = switch (b.kind) {
      'credit' => 'Shopping credit',
      'discount' => 'Discount',
      _ => 'Perk (text only)',
    };

    return Card(
      key: ObjectKey(b),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(benefitIcon(b.kind), size: 20, color: goldColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: i == 0 ? null : () => _move(i, -1),
                ),
                IconButton(
                  tooltip: 'Move down',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: i == _benefits.length - 1 ? null : () => _move(i, 1),
                ),
                IconButton(
                  tooltip: 'Remove benefit',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  onPressed: () => _removeBenefit(i),
                ),
              ],
            ),
            if (server('kind') != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(server('kind')!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (b.kind != 'perk') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: b.amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => _vAmount(b, v),
                forceErrorText: server(b.kind == 'credit' ? 'credit_cents' : 'discount_percent'),
                decoration: InputDecoration(
                  labelText: b.kind == 'credit' ? 'Credit amount (€)' : 'Discount (%)',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: b.description,
              minLines: 1,
              maxLines: 2,
              maxLength: 300,
              onChanged: (_) => b.descriptionTouched = true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _vBenefitDescription,
              forceErrorText: server('description'),
              decoration: InputDecoration(
                labelText: 'Line shown to customers',
                helperText: b.kind == 'perk'
                    ? 'e.g. Access to exclusive offers'
                    : 'Filled in from the amount, you can reword it.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit plan' : 'New plan')),
        body: Center(child: CircularProgressIndicator(color: goldColor)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit plan' : 'New plan')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingData = true;
                      _loadError = null;
                    });
                    _init();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: goldColor),
                    foregroundColor: goldColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final endedRateSelected = _taxRates.any((t) => t['id'] == _taxRateId && t['ended'] == true);
    final full = _benefits.length >= _maxBenefits;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit plan' : 'New plan'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text(
              'code',
              'Code',
              _code,
              _vCode,
              enabled: !_editing,
              helper: _editing ? 'The code cannot be changed.' : 'e.g. entry or gold',
            ),
            _text('name', 'Name', _name, _vName, helper: 'e.g. Entry Membership'),
            _text(
              'description',
              'Short description (shown under the name)',
              _desc,
              _vDesc,
              maxLines: 2,
              helper: 'e.g. Perfect for getting to know each other',
            ),
            if (_editing && !_hasProduct)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'This plan has no product yet, so it cannot be bought. Set a price and a tax rate to put it on sale.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            _text(
              'price_cents',
              'Price (€, incl. VAT)',
              _price,
              _vPrice,
              type: const TextInputType.numberWithOptions(decimal: true),
            ),
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
                      child: Text(
                        '${t['code']} (${t['rate_percent']}%)${t['ended'] == true ? ' · ended' : ''}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _taxRateId = v),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: goldColor,
              title: Text(
                'Available to buy',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Turning this off hides the plan. Existing members keep their membership.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const Divider(height: 32),
            Text(
              'Benefits',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'What a member gets, in the order customers read it. Use the arrows to reorder. '
              'A plan can have one shopping credit and one discount, plus any number of perks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _benefits.length; i++) _benefitCard(i),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: full || _has('credit') ? null : () => _addBenefit('credit'),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Shopping credit'),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: goldColor)),
                ),
                OutlinedButton.icon(
                  onPressed: full || _has('discount') ? null : () => _addBenefit('discount'),
                  icon: const Icon(Icons.sell_outlined, size: 18),
                  label: const Text('Discount'),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: goldColor)),
                ),
                OutlinedButton.icon(
                  onPressed: full ? null : () => _addBenefit('perk'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Perk'),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: goldColor)),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 24),
            LoadingButton(
              label: _editing ? 'Save changes' : 'Create plan',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}