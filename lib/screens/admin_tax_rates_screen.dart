import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

typedef TaxRateData = Map<String, dynamic>;

class AdminTaxRatesScreen extends StatefulWidget {
  const AdminTaxRatesScreen({super.key});

  @override
  State<AdminTaxRatesScreen> createState() => _AdminTaxRatesScreenState();
}

class _AdminTaxRatesScreenState extends State<AdminTaxRatesScreen> {
  List<TaxRateData> _rates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rates = await ApiService.instance.adminTaxRates(all: true);
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _state(TaxRateData r) {
    if (r['is_current'] == true) return 'Current';
    final to = r['valid_to'] as String?;
    return to != null && to.compareTo(_date(DateTime.now().toUtc())) < 0 ? 'Ended' : 'Upcoming';
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewRateDialog(),
    );
    if (created == true) _load();
  }

  Future<void> _setEnd(TaxRateData r, String? validTo) async {
    try {
      await ApiService.instance.adminEndTaxRate(r['id'] as int, validTo);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickEnd(TaxRateData r) async {
    final from = DateTime.parse(r['valid_from'] as String);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now.isBefore(from) ? from : now,
      firstDate: from,
      lastDate: DateTime(2100),
      helpText: 'Last day this rate applies',
    );
    if (picked != null) _setEnd(r, _date(picked));
  }

  void _actions(TaxRateData r) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Set end date…'),
              onTap: () {
                Navigator.pop(context);
                _pickEnd(r);
              },
            ),
            if (r['valid_to'] != null)
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Remove end date'),
                onTap: () {
                  Navigator.pop(context);
                  _setEnd(r, null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(TaxRateData r) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final isDark = theme.brightness == Brightness.dark;

    final state = _state(r);
    final to = r['valid_to'] as String?;
    final products = r['product_count'] as int;
    final shipping = r['shipping_rate_count'] as int;
    final stale = state == 'Ended' && (products > 0 || shipping > 0);

    Color badgeColor;
    Color textColor;

    switch (state) {
      case 'Current':
        badgeColor = goldColor.withValues(alpha: 0.15);
        textColor = goldColor;
        break;
      case 'Ended':
        badgeColor = theme.colorScheme.error.withValues(alpha: 0.12);
        textColor = theme.colorScheme.error;
        break;
      default: // Upcoming
        badgeColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    }

    return ListTile(
      key: ValueKey(r['id']),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: () => _actions(r),
      title: Text(
        '${r['code']}  ·  ${r['country_code']}  ·  ${formatPercent(r['rate_percent'] as num)}%',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          'from ${r['valid_from']} ${to == null ? '(no end date)' : 'until $to'}\n'
          '$products product(s) · $shipping shipping rate(s)'
          '${stale ? '\nStill used after its end date: move them to a current rate.' : ''}',
          style: stale
              ? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)
              : theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ),
      isThreeLine: true,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          state,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Widget body;

    if (_loading) {
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'A rate\'s percentage never changes. To change a tax rate, create a new rate and end the old one: '
                'orders and products keep the rate they were created with.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            for (final r in _rates) _tile(r),
            if (_rates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No tax rates yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Rates'),
        elevation: 0,
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: goldColor,
        elevation: 2,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'New rate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NewRateDialog extends StatefulWidget {
  const _NewRateDialog();

  @override
  State<_NewRateDialog> createState() => _NewRateDialogState();
}

class _NewRateDialogState extends State<_NewRateDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _country = TextEditingController(text: 'DE');
  final _rate = TextEditingController();
  final _fromText = TextEditingController();
  final _toText = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final c in [_code, _country, _rate, _fromText, _toText]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) => showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await ApiService.instance.adminCreateTaxRate({
        'code': _code.text.trim().toUpperCase(),
        'country_code': _country.text.trim().toUpperCase(),
        'rate_percent': _rate.text.trim().replaceAll(',', '.'),
        'valid_from': _fromText.text,
        'valid_to': _to == null ? null : _toText.text,
      });
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
        'New tax rate',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => RegExp(r'^[A-Z][A-Z0-9_]{1,39}$').hasMatch((v ?? '').trim().toUpperCase())
                    ? null
                    : '2 to 40 characters: letters, numbers and _',
                forceErrorText: _serverErrors['code'],
                decoration: const InputDecoration(labelText: 'Code', helperText: 'e.g. DE_REDUCED_2027'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _country,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => RegExp(r'^[A-Z]{2}$').hasMatch((v ?? '').trim().toUpperCase())
                    ? null
                    : 'Two letters, e.g. DE',
                forceErrorText: _serverErrors['country_code'],
                decoration: const InputDecoration(labelText: 'Country', counterText: ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  final s = (v ?? '').trim().replaceAll(',', '.');
                  final ok = RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(s) && double.parse(s) <= 100;
                  return ok ? null : 'A number from 0 to 100, at most 2 decimals.';
                },
                forceErrorText: _serverErrors['rate_percent'],
                decoration: const InputDecoration(labelText: 'Rate (%)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fromText,
                readOnly: true,
                validator: (v) => (v ?? '').isEmpty ? 'Choose a start date.' : null,
                forceErrorText: _serverErrors['valid_from'],
                decoration: const InputDecoration(labelText: 'Valid from', suffixIcon: Icon(Icons.calendar_today, size: 20)),
                onTap: () async {
                  final d = await _pick(_from);
                  if (d != null) {
                    setState(() {
                      _from = d;
                      _fromText.text = d.toIso8601String().substring(0, 10);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _toText,
                readOnly: true,
                validator: (v) => _to != null && _from != null && _to!.isBefore(_from!)
                    ? 'The end date cannot be before the start date.'
                    : null,
                forceErrorText: _serverErrors['valid_to'],
                decoration: InputDecoration(
                  labelText: 'Valid until (optional)',
                  suffixIcon: _to == null
                      ? const Icon(Icons.calendar_today, size: 20)
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'No end date',
                          onPressed: () => setState(() {
                            _to = null;
                            _toText.clear();
                          }),
                        ),
                ),
                onTap: () async {
                  final d = await _pick(_to ?? _from);
                  if (d != null) {
                    setState(() {
                      _to = d;
                      _toText.text = d.toIso8601String().substring(0, 10);
                    });
                  }
                },
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
              : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}