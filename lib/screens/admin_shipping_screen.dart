import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/countries.dart';
import '../utils/money.dart';

typedef ShippingData = Map<String, dynamic>;

const _maxOrderCents = 100000000; // 1,000,000.00
const _maxPriceCents = 100000; // 1,000.00

String _euros(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

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
  List<ShippingData> _methods = [];
  List<ShippingData> _taxRates = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

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
        _methods = (results[0] as List<dynamic>).cast<ShippingData>();
        _taxRates = (results[1] as List<dynamic>).cast<ShippingData>();
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

  Future<void> _methodDialog([ShippingData? method]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MethodDialog(method: method),
    );
    if (saved == true) _load();
  }

  Future<void> _rateDialog(ShippingData method, {ShippingData? rate, String? country}) async {
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

  Future<void> _toggle(ShippingData m) async {
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

  Future<void> _deleteRate(ShippingData r) async {
    final key = 'r${r['id']}';
    if (_busy.contains(key)) return;

    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete price range?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${_rangeText(r['min_cents'] as int, r['max_cents'] as int?)} will be removed.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
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

  String _gapText(ShippingData g) {
    final from = g['from_cents'] as int;
    final to = g['to_cents'] as int?;
    if (to == null) return 'Orders of ${formatCents(from)} and above have';
    return from == 0 ? 'Orders under ${formatCents(to)} have' : 'Orders from ${formatCents(from)} to under ${formatCents(to)} have';
  }

  Widget _rateTile(ShippingData m, ShippingData r) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final price = r['price_cents'] as int;
    final busy = _busy.contains('r${r['id']}');

    return ListTile(
      key: ValueKey('r${r['id']}'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: () => _rateDialog(m, rate: r),
      title: Text(
        _rangeText(r['min_cents'] as int, r['max_cents'] as int?),
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'VAT ${r['tax_rate_code']} (${formatPercent(r['tax_rate_percent'] as num)}%)',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            price == 0 ? 'Free' : formatCents(price),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: price == 0 ? goldColor : theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            tooltip: 'Delete range',
            icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error.withValues(alpha: 0.8)),
            onPressed: busy ? null : () => _deleteRate(r),
          ),
        ],
      ),
    );
  }

  List<Widget> _country(ShippingData m, ShippingData c) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final code = c['country_code'] as String;
    final rates = (c['rates'] as List<dynamic>).cast<ShippingData>();
    final gaps = (c['gaps'] as List<dynamic>).cast<ShippingData>();

    return [
      Divider(height: 20, color: theme.dividerColor.withValues(alpha: 0.15)),
      Row(
        children: [
          Expanded(
            child: Text(
              '${countryName(code)} ($code)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            onPressed: () => _rateDialog(m, country: code),
            icon: Icon(Icons.add, size: 16, color: goldColor),
            label: Text(
              'Add range',
              style: TextStyle(color: goldColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      for (final r in rates) _rateTile(m, r),
      for (final g in gaps)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '${_gapText(g)} no shipping price: customers cannot check out.',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ),
    ];
  }

  Widget _method(ShippingData m) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final active = m['active'] == true;
    final countries = (m['countries'] as List<dynamic>).cast<ShippingData>();

    return Container(
      key: ValueKey('m${m['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['name'] as String,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      m['code'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rename',
                icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                onPressed: () => _methodDialog(m),
              ),
              Switch(
                value: active,
                activeColor: goldColor,
                onChanged: _busy.contains('m${m['id']}') ? null : (_) => _toggle(m),
              ),
            ],
          ),
          if (!active)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Inactive: customers cannot choose this method.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          if (countries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No prices yet. Add a price range to use this method.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          for (final c in countries) ..._country(m, c),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _rateDialog(m),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add price range'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: goldColor),
              foregroundColor: goldColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Widget body;

    if (_loading && _methods.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: goldColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Each range applies from its start value up to, but not including, its upper limit. '
                'The order value is the price of the shipped goods including VAT. '
                'A range with price 0 is free shipping. Orders in a gap have no delivery price.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            if (_methods.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No shipping methods yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            for (final m in _methods) _method(m),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Methods'),
        elevation: 0,
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _methodDialog(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: goldColor,
        elevation: 2,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'New method',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MethodDialog extends StatefulWidget {
  final ShippingData? method;
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
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _editing ? 'Rename method' : 'New shipping method',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _code,
              enabled: !_editing,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch((v ?? '').trim()) && (v ?? '').trim().length <= 40
                  ? null
                  : 'Lowercase letters and numbers separated by single hyphens.',
              forceErrorText: _serverErrors['code'],
              decoration: InputDecoration(
                labelText: 'Code',
                helperText: _editing ? 'The code cannot be changed.' : 'e.g. standard or express',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final s = (v ?? '').trim();
                return s.isEmpty || s.length > 100 ? 'Name must be 1 to 100 characters.' : null;
              },
              forceErrorText: _serverErrors['name'],
              decoration: const InputDecoration(
                labelText: 'Name shown to customers',
                helperText: 'e.g. Standard shipping (DHL)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: goldColor,
            elevation: 0,
          ),
          child: _saving
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: goldColor))
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _RateDialog extends StatefulWidget {
  final int methodId;
  final String methodName;
  final ShippingData? rate;
  final String? initialCountry;
  final List<ShippingData> taxRates;

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
  late final List<ShippingData> _taxRates = _withOwnRate();

  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.rate != null;

  List<ShippingData> _withOwnRate() {
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
    if (s.isEmpty) return null;
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

    final from = parseEuroToCents(_from.text.trim())!;
    final untilText = _until.text.trim();
    final until = untilText.isEmpty ? null : parseEuroToCents(untilText);
    final price = parseEuroToCents(_price.text.trim())!;

    final ShippingData body;
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
        Navigator.pop(context, false);
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
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    final countryItems = [
      for (final c in countries) DropdownMenuItem<String>(value: c.code, child: Text('${c.name} (${c.code})')),
      if (countryByCode(_country) == null) DropdownMenuItem<String>(value: _country, child: Text(_country)),
    ];
    final ended = _taxRates.any((t) => t['id'] == _taxRateId && t['ended'] == true);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _editing ? 'Edit price range' : 'New price range',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.methodName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _country,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Country', errorText: _serverErrors['country_code']),
                items: countryItems,
                onChanged: _saving ? null : (v) => setState(() => _country = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _from,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vFrom,
                forceErrorText: _serverErrors['min_gross_cents'],
                decoration: const InputDecoration(
                  labelText: 'Order value from (€)',
                  helperText: 'Included. Use 0 for the first range.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _until,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vUntil,
                forceErrorText: _serverErrors['max_gross_cents'],
                decoration: const InputDecoration(
                  labelText: 'Up to, not including (€)',
                  helperText: 'Leave empty for no upper limit.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vPrice,
                forceErrorText: _serverErrors['price_cents'],
                decoration: const InputDecoration(
                  labelText: 'Shipping price (€, incl. VAT)',
                  helperText: '0 means free shipping.',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _taxRateId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Tax rate',
                  helperText: ended ? 'This rate has ended. Select a current rate if updating.' : null,
                  helperMaxLines: 2,
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
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: goldColor,
            elevation: 0,
          ),
          child: _saving
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: goldColor))
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}