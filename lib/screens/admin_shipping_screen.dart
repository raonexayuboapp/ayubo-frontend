import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/countries.dart';
import '../utils/money.dart';

const _maxOrderCents = 100000000; // the server's limit: 1,000,000.00
const _maxPriceCents = 100000; // 1,000.00

String _euros(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// "Under €50.00", "€50.00 and above", "€20.00 to under €50.00"
String _rangeText(int min, int? max) {
  if (max == null) return min == 0 ? 'Any order value' : '${formatCents(min)} and above';
  return min == 0 ? 'Under ${formatCents(max)}' : '${formatCents(min)} to under ${formatCents(max)}';
}

class AdminShippingScreen extends StatefulWidget {
  const AdminShippingScreen({super.key});

  @override
  State<AdminShippingScreen> createState() => _AdminShippingScreenState();
}

class _AdminShippingScreenState extends State<AdminShippingScreen> {
  List<Map<String, dynamic>> _methods = [];
  List<Map<String, dynamic>> _taxRates = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {}; // 'm<id>' for methods, 'r<id>' for ranges

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        ApiService.instance.adminShippingMethods(),
        ApiService.instance.adminTaxRates(),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = results[0] as List<Map<String, dynamic>>;
        _taxRates = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_methods.isEmpty) _error = e.message;
      });
      if (_methods.isNotEmpty) _snack(e.message);
    }
  }

  Future<void> _methodDialog([Map<String, dynamic>? method]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MethodDialog(method: method),
    );
    if (saved == true) _load();
  }

  Future<void> _rateDialog(Map<String, dynamic> method, {Map<String, dynamic>? rate, String? country}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RateDialog(
        methodId: method['id'] as int,
        methodName: method['name'] as String,
        rate: rate,
        initialCountry: country,
        taxRates: _taxRates,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> m) async {
    final key = 'm${m['id']}';
    if (_busy.contains(key)) return;

    setState(() => _busy.add(key));
    try {
      await ApiService.instance.adminUpdateShippingMethod(m['id'] as int, {'active': m['active'] != true});
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _deleteRate(Map<String, dynamic> r) async {
    final key = 'r${r['id']}';
    if (_busy.contains(key)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete price range?'),
        content: Text('${_rangeText(r['min_cents'] as int, r['max_cents'] as int?)} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy.add(key));
    try {
      await ApiService.instance.adminDeleteShippingRate(r['id'] as int);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  String _gapText(Map<String, dynamic> g) {
    final from = g['from_cents'] as int;
    final to = g['to_cents'] as int?;
    if (to == null) return 'Orders of ${formatCents(from)} and above have';
    return from == 0 ? 'Orders under ${formatCents(to)} have' : 'Orders from ${formatCents(from)} to under ${formatCents(to)} have';
  }

  Widget _rateTile(Map<String, dynamic> m, Map<String, dynamic> r) {
    final price = r['price_cents'] as int;
    final busy = _busy.contains('r${r['id']}');

    return ListTile(
      key: ValueKey('r${r['id']}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => _rateDialog(m, rate: r),
      title: Text(_rangeText(r['min_cents'] as int, r['max_cents'] as int?)),
      subtitle: Text('VAT ${r['tax_rate_code']} (${formatPercent(r['tax_rate_percent'] as num)}%)'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(price == 0 ? 'Free' : formatCents(price),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: busy ? null : () => _deleteRate(r),
        ),
      ]),
    );
  }

  List<Widget> _country(Map<String, dynamic> m, Map<String, dynamic> c) {
    final theme = Theme.of(context);
    final code = c['country_code'] as String;
    final rates = (c['rates'] as List<dynamic>).cast<Map<String, dynamic>>();
    final gaps = (c['gaps'] as List<dynamic>).cast<Map<String, dynamic>>();

    return [
      const Divider(height: 24),
      Row(children: [
        Expanded(child: Text('${countryName(code)} ($code)', style: theme.textTheme.titleSmall)),
        TextButton(onPressed: () => _rateDialog(m, country: code), child: const Text('Add range')),
      ]),
      for (final r in rates) _rateTile(m, r),
      for (final g in gaps)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_gapText(g)} no shipping price: customers cannot check out.',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ),
    ];
  }

  Widget _method(Map<String, dynamic> m) {
    final theme = Theme.of(context);
    final active = m['active'] == true;
    final countries = (m['countries'] as List<dynamic>).cast<Map<String, dynamic>>();

    return Card(
      key: ValueKey('m${m['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['name'] as String, style: theme.textTheme.titleMedium),
                Text(m['code'] as String, style: theme.textTheme.bodySmall),
              ]),
            ),
            IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_outlined), onPressed: () => _methodDialog(m)),
            Switch(value: active, onChanged: _busy.contains('m${m['id']}') ? null : (_) => _toggle(m)),
          ]),
          if (!active)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Inactive: customers cannot choose this method.', style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (countries.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('No prices yet. Add a price range to use this method.')),
          for (final c in countries) ..._country(m, c),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _rateDialog(m),
            icon: const Icon(Icons.add),
            label: const Text('Add price range'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _methods.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Each range applies from its start value up to, but not including, its upper limit. '
                    'The order value is the price of the shipped goods including VAT. '
                    'A range with price 0 is free shipping. Orders in a gap have no delivery price.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_methods.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No shipping methods yet.'))),
            for (final m in _methods) Padding(padding: const EdgeInsets.only(bottom: 8), child: _method(m)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shipping')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _methodDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New method'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Create a method (code + name) or rename one. It owns its controllers, so closing it cannot leave one behind.
class _MethodDialog extends StatefulWidget {
  final Map<String, dynamic>? method;
  const _MethodDialog({this.method});

  @override
  State<_MethodDialog> createState() => _MethodDialogState();
}

class _MethodDialogState extends State<_MethodDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: (widget.method?['code'] as String?) ?? '');
  late final _name = TextEditingController(text: (widget.method?['name'] as String?) ?? '');
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.method != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (_editing) {
        await ApiService.instance.adminUpdateShippingMethod(widget.method!['id'] as int, {'name': _name.text.trim()});
      } else {
        await ApiService.instance.adminCreateShippingMethod({'code': _code.text.trim(), 'name': _name.text.trim()});
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Rename method' : 'New shipping method'),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _code,
            enabled: !_editing,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch((v ?? '').trim()) && (v ?? '').trim().length <= 40
                ? null
                : 'Lowercase letters and numbers separated by single hyphens.',
            forceErrorText: _serverErrors['code'],
            decoration: InputDecoration(labelText: 'Code', helperText: _editing ? 'The code cannot be changed.' : 'e.g. standard or express'),
          ),
          TextFormField(
            controller: _name,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              final s = (v ?? '').trim();
              return s.isEmpty || s.length > 100 ? 'Name must be 1 to 100 characters.' : null;
            },
            forceErrorText: _serverErrors['name'],
            decoration: const InputDecoration(labelText: 'Name shown to customers', helperText: 'e.g. Standard shipping (DHL)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Create or edit one price range. When editing, only what changed is sent, so a stale form cannot overwrite
/// another admin's edit, and a range whose tax rate has ended can still be changed.
class _RateDialog extends StatefulWidget {
  final int methodId;
  final String methodName;
  final Map<String, dynamic>? rate;
  final String? initialCountry;
  final List<Map<String, dynamic>> taxRates;

  const _RateDialog({
    required this.methodId,
    required this.methodName,
    required this.taxRates,
    this.rate,
    this.initialCountry,
  });

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  final _form = GlobalKey<FormState>();
  late final _from = TextEditingController(text: widget.rate == null ? '0' : _euros(widget.rate!['min_cents'] as int));
  late final _until = TextEditingController(
      text: widget.rate?['max_cents'] == null ? '' : _euros(widget.rate!['max_cents'] as int));
  late final _price = TextEditingController(text: widget.rate == null ? '' : _euros(widget.rate!['price_cents'] as int));

  late String _country = (widget.rate?['country_code'] as String?) ?? widget.initialCountry ?? 'DE';
  late int? _taxRateId = (widget.rate?['tax_rate_id'] as int?) ?? (widget.taxRates.isEmpty ? null : widget.taxRates.first['id'] as int);
  late final List<Map<String, dynamic>> _taxRates = _withOwnRate();

  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.rate != null;

  /// The range's own tax rate may have ended. Keep it in the list so the dropdown stays valid.
  List<Map<String, dynamic>> _withOwnRate() {
    final list = [...widget.taxRates];
    final r = widget.rate;
    if (r != null && !list.any((t) => t['id'] == r['tax_rate_id'])) {
      list.add({'id': r['tax_rate_id'], 'code': r['tax_rate_code'], 'rate_percent': r['tax_rate_percent'], 'ended': true});
    }
    return list;
  }

  @override
  void dispose() {
    _from.dispose();
    _until.dispose();
    _price.dispose();
    super.dispose();
  }

  String? _vFrom(String? v) {
    final c = parseEuroToCents((v ?? '').trim());
    if (c == null) return 'Enter an amount like 0 or 50.';
    return c > _maxOrderCents ? 'The amount is too high.' : null;
  }

  String? _vUntil(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // no upper limit
    final c = parseEuroToCents(s);
    if (c == null) return 'Enter an amount like 50, or leave empty.';
    final from = parseEuroToCents(_from.text.trim());
    if (from != null && c <= from) return 'Must be higher than the start.';
    return c > _maxOrderCents ? 'The amount is too high.' : null;
  }

  String? _vPrice(String? v) {
    final c = parseEuroToCents((v ?? '').trim());
    if (c == null) return 'Enter an amount like 4.90, or 0 for free shipping.';
    return c > _maxPriceCents ? 'The most you can set is 1000.00.' : null;
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    final from = parseEuroToCents(_from.text.trim())!; // safe: validate() accepted these
    final untilText = _until.text.trim();
    final until = untilText.isEmpty ? null : parseEuroToCents(untilText);
    final price = parseEuroToCents(_price.text.trim())!;

    final Map<String, dynamic> body;
    if (_editing) {
      final r = widget.rate!;
      body = {
        if (_country != r['country_code']) 'country_code': _country,
        if (from != r['min_cents']) 'min_gross_cents': from,
        if (until != r['max_cents']) 'max_gross_cents': until,
        if (price != r['price_cents']) 'price_cents': price,
        if (_taxRateId != r['tax_rate_id']) 'tax_rate_id': _taxRateId,
      };
      if (body.isEmpty) {
        Navigator.pop(context, false); // nothing changed
        return;
      }
    } else {
      body = {
        'country_code': _country,
        'min_gross_cents': from,
        'max_gross_cents': until,
        'price_cents': price,
        'tax_rate_id': _taxRateId,
      };
    }

    setState(() => _saving = true);

    try {
      if (_editing) {
        await ApiService.instance.adminUpdateShippingRate(widget.rate!['id'] as int, body);
      } else {
        await ApiService.instance.adminCreateShippingRate(widget.methodId, body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final countryItems = [
      for (final c in countries) DropdownMenuItem<String>(value: c.code, child: Text('${c.name} (${c.code})')),
      // A range made elsewhere may use a country that is not in our list: keep it selectable.
      if (countryByCode(_country) == null) DropdownMenuItem<String>(value: _country, child: Text(_country)),
    ];
    final ended = _taxRates.any((t) => t['id'] == _taxRateId && t['ended'] == true);

    return AlertDialog(
      title: Text(_editing ? 'Edit price range' : 'New price range'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.methodName, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _country,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Country', errorText: _serverErrors['country_code']),
              items: countryItems,
              onChanged: _saving ? null : (v) => setState(() => _country = v!),
            ),
            TextFormField(
              controller: _from,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _vFrom,
              forceErrorText: _serverErrors['min_gross_cents'],
              decoration: const InputDecoration(labelText: 'Order value from (€)', helperText: 'Included. Use 0 for the first range.'),
            ),
            TextFormField(
              controller: _until,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _vUntil,
              forceErrorText: _serverErrors['max_gross_cents'],
              decoration: const InputDecoration(
                  labelText: 'Up to, not including (€)', helperText: 'Leave empty for no upper limit.'),
            ),
            TextFormField(
              controller: _price,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _vPrice,
              forceErrorText: _serverErrors['price_cents'],
              decoration: const InputDecoration(labelText: 'Shipping price (€, incl. VAT)', helperText: '0 means free shipping.'),
            ),
            DropdownButtonFormField<int>(
              value: _taxRateId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Tax rate',
                helperText: ended ? 'This rate has ended. It still works here, but a current rate should replace it.' : null,
                helperMaxLines: 3,
                errorText: _serverErrors['tax_rate_id'],
              ),
              validator: (v) => v == null ? 'Choose a tax rate.' : null,
              items: [
                for (final t in _taxRates)
                  DropdownMenuItem<int>(
                    value: t['id'] as int,
                    child: Text('${t['code']} (${t['rate_percent']}%)${t['ended'] == true ? ' · ended' : ''}'),
                  ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _taxRateId = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}