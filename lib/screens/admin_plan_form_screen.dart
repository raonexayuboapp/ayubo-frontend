import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/loading_button.dart';

/// One editable benefit line. It owns its controllers, so the form must dispose them.
class _BenefitRow {
  final TextEditingController title;
  final TextEditingController discount;
  // Not editable here, but kept so saving doesn't silently erase them (the server replaces the whole list).
  final String? description;
  final bool isActive;

  _BenefitRow({String title = '', String discount = '', this.description, this.isActive = true})
      : title = TextEditingController(text: title),
        discount = TextEditingController(text: discount);

  factory _BenefitRow.fromJson(Map<String, dynamic> b) {
    final d = (b['discount_percent'] as num).toDouble();
    return _BenefitRow(
      title: b['title'] as String,
      discount: d == d.roundToDouble() ? d.toInt().toString() : d.toString(),
      description: b['description'] as String?,
      isActive: b['is_active'] != false,
    );
  }

  void dispose() {
    title.dispose();
    discount.dispose();
  }
}

class AdminPlanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? plan; // null = create, otherwise edit
  const AdminPlanFormScreen({super.key, this.plan});

  @override
  State<AdminPlanFormScreen> createState() => _AdminPlanFormScreenState();
}

class _AdminPlanFormScreenState extends State<AdminPlanFormScreen> {
  final _form = GlobalKey<FormState>();

  late final _code = TextEditingController(text: (widget.plan?['code'] as String?) ?? '');
  late final _name = TextEditingController(text: (widget.plan?['name'] as String?) ?? '');
  late final _desc = TextEditingController(text: (widget.plan?['description'] as String?) ?? '');
  late final _price = TextEditingController(text: _euros(widget.plan?['price_cents'] as int?));
  late final _bonus = TextEditingController(text: _euros(widget.plan?['bonus_cents'] as int?));
  late final _months = TextEditingController(text: '${widget.plan?['duration_months'] ?? 12}');
  late final _sort = TextEditingController(text: '${widget.plan?['sort_order'] ?? 0}');

  late String? _level = widget.plan?['membership_level'] as String?;
  late bool _active = widget.plan?['is_active'] != false;
  late final List<_BenefitRow> _benefits = [
    for (final b in (widget.plan?['benefits'] as List<dynamic>? ?? []))
      _BenefitRow.fromJson(b as Map<String, dynamic>),
  ];

  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.plan != null;

  /// 10500 -> "105.00". Integer maths only, so there is no floating-point rounding.
  static String _euros(int? cents) =>
      cents == null ? '' : '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final c in [_code, _name, _desc, _price, _bonus, _months, _sort]) {
      c.dispose();
    }
    for (final b in _benefits) {
      b.dispose();
    }
    super.dispose();
  }

  // ---------- validation (the server checks everything again) ----------

  String? _vCode(String? v) => RegExp(r'^[a-z0-9][a-z0-9_-]{1,49}$').hasMatch((v ?? '').trim())
      ? null
      : '2 to 50 characters: lowercase letters, numbers, - or _.';

  String? _vName(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 100 ? 'Name must be 1 to 100 characters.' : null;
  }

  String? _vDesc(String? v) => (v ?? '').trim().length > 1000 ? 'Maximum 1000 characters.' : null;

  String? _vPrice(String? v) {
    final cents = parseEuroToCents(v ?? '');
    if (cents == null) return 'Enter an amount like 100 or 100.50.';
    if (cents < 1 || cents > 1000000) return 'Price must be between 0.01 and 10000.';
    return null;
  }

  String? _vBonus(String? v) {
    if ((v ?? '').trim().isEmpty) return null; // empty means no bonus
    final bonus = parseEuroToCents(v!);
    if (bonus == null) return 'Enter an amount like 5 or 5.50.';
    if (bonus > 1000000) return 'Bonus is too large.';
    final price = parseEuroToCents(_price.text);
    if (price != null && bonus > price) return 'Bonus cannot be higher than the price.';
    return null;
  }

  String? _vInt(String? v, int min, int max) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < min || n > max ? 'Enter a whole number from $min to $max.' : null;
  }

  String? _vBenefitTitle(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 100 ? 'Title must be 1 to 100 characters.' : null;
  }

  String? _vDiscount(String? v) {
    final d = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    return d == null || d <= 0 || d > 100 ? 'Enter a discount above 0 and up to 100.' : null;
  }

  // ---------- benefits list ----------

  void _addBenefit() => setState(() => _benefits.add(_BenefitRow()));

  void _removeBenefit(int i) {
    final row = _benefits[i];
    setState(() => _benefits.removeAt(i));
    // Dispose after the frame: the removed field is still on screen until it finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  // ---------- save ----------

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    // Safe to use "!" and parse(): the validators above already accepted these values.
    final body = <String, dynamic>{
      if (!_editing) 'code': _code.text.trim(),
      'name': _name.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'membership_level': _level,
      'price_cents': parseEuroToCents(_price.text)!,
      'bonus_cents': _bonus.text.trim().isEmpty ? 0 : parseEuroToCents(_bonus.text)!,
      'duration_months': int.parse(_months.text.trim()),
      'sort_order': int.parse(_sort.text.trim()),
      'is_active': _active,
      'benefits': [
        for (final b in _benefits)
          {
            'title': b.title.text.trim(),
            'discount_percent': double.parse(b.discount.text.trim().replaceAll(',', '.')),
            if (b.description != null) 'description': b.description,
            'is_active': b.isActive,
          },
      ],
    };

    try {
      if (_editing) {
        await ApiService.instance.adminUpdatePlan(widget.plan!['id'] as int, body);
      } else {
        await ApiService.instance.adminCreatePlan(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errors = Map<String, String>.from(e.fieldErrors);
      if (e.statusCode == 409) errors['code'] = e.message; // duplicate plan code
      setState(() {
        _serverErrors = errors;
        // Errors with no field of their own are shown at the bottom.
        final general = [errors['benefits'], errors['is_active'], errors['membership_level']]
            .whereType<String>()
            .join('\n');
        _error = e.fieldErrors.isEmpty && e.statusCode != 409
            ? e.message
            : (general.isEmpty ? null : general);
        _loading = false;
      });
    }
  }

  // ---------- UI ----------

  Widget _text(
      String serverKey,
      String label,
      TextEditingController c,
      String? Function(String?) validator, {
        TextInputType? type,
        bool enabled = true,
        String? helper,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        keyboardType: type,
        maxLines: maxLines,
        textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const money = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit plan' : 'New plan')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text('code', 'Code', _code, _vCode,
                enabled: !_editing, helper: _editing ? 'The code cannot be changed.' : 'e.g. family-100'),
            _text('name', 'Name', _name, _vName),
            _text('description', 'Description (optional)', _desc, _vDesc, maxLines: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String?>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Level'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('None')),
                  DropdownMenuItem(value: 'starter', child: Text('Starter')),
                  DropdownMenuItem(value: 'premium', child: Text('Premium')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP')),
                ],
                onChanged: (v) => setState(() => _level = v),
              ),
            ),
            _text('price_cents', 'Price (€)', _price, _vPrice, type: money),
            _text('bonus_cents', 'Bonus (€)', _bonus, _vBonus, type: money, helper: 'Added on top of the price.'),
            _text('duration_months', 'Valid for (months)', _months, (v) => _vInt(v, 1, 60),
                type: TextInputType.number),
            _text('sort_order', 'Sort order', _sort, (v) => _vInt(v, 0, 10000),
                type: TextInputType.number, helper: 'Lower numbers are shown first.'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available to buy'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const Divider(height: 32),
            Text('Benefits (discounts)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'The highest discount applies when a voucher is used.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _benefits.length; i++)
              Padding(
                key: ObjectKey(_benefits[i]),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _benefits[i].title,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _vBenefitTitle,
                        forceErrorText: _serverErrors['benefits.$i.title'],
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _benefits[i].discount,
                        keyboardType: money,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _vDiscount,
                        forceErrorText: _serverErrors['benefits.$i.discount_percent'],
                        decoration: const InputDecoration(labelText: 'Discount %'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove benefit',
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeBenefit(i),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addBenefit,
                icon: const Icon(Icons.add),
                label: const Text('Add benefit'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            LoadingButton(label: _editing ? 'Save changes' : 'Create plan', loading: _loading, onPressed: _save),
          ],
        ),
      ),
    );
  }
}