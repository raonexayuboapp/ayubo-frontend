import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

class AdminTaxRatesScreen extends StatefulWidget {
  const AdminTaxRatesScreen({super.key});

  @override
  State<AdminTaxRatesScreen> createState() => _AdminTaxRatesScreenState();
}

class _AdminTaxRatesScreenState extends State<AdminTaxRatesScreen> {
  List<Map<String, dynamic>> _rates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10); // YYYY-MM-DD

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

  String _state(Map<String, dynamic> r) {
    if (r['is_current'] == true) return 'Current';
    final to = r['valid_to'] as String?;
    return to != null && to.compareTo(_date(DateTime.now().toUtc())) < 0 ? 'Ended' : 'Upcoming';
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(context: context, builder: (_) => const _NewRateDialog());
    if (created == true) _load();
  }

  Future<void> _setEnd(Map<String, dynamic> r, String? validTo) async {
    try {
      await ApiService.instance.adminEndTaxRate(r['id'] as int, validTo);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickEnd(Map<String, dynamic> r) async {
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

  void _actions(Map<String, dynamic> r) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
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
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'A rate\'s percentage never changes. To change a tax rate, create a new rate and end the old one: '
                    'orders and products keep the rate they were created with.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final r in _rates) _tile(r),
            if (_rates.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No tax rates yet.'))),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tax rates')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New rate'),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> r) {
    final state = _state(r);
    final to = r['valid_to'] as String?;
    final products = r['product_count'] as int;
    final shipping = r['shipping_rate_count'] as int;
    final stale = state == 'Ended' && (products > 0 || shipping > 0);

    return ListTile(
      key: ValueKey(r['id']),
      onTap: () => _actions(r),
      title: Text('${r['code']}  ·  ${r['country_code']}  ·  ${formatPercent(r['rate_percent'] as num)}%'),
      subtitle: Text(
        'from ${r['valid_from']} ${to == null ? '(no end date)' : 'until $to'}\n'
            '$products product(s) · $shipping shipping rate(s)'
            '${stale ? '\nStill used after its end date: move them to a current rate.' : ''}',
        style: stale ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
      ),
      isThreeLine: true,
      trailing: Chip(label: Text(state), visualDensity: VisualDensity.compact),
    );
  }
}

/// The "new rate" form in a dialog. It owns its controllers, so closing it cannot leave one behind.
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
        'rate_percent': _rate.text.trim().replaceAll(',', '.'), // sent as text so the percentage stays exact
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
    return AlertDialog(
      title: const Text('New tax rate'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            TextFormField(
              controller: _fromText,
              readOnly: true,
              validator: (v) => (v ?? '').isEmpty ? 'Choose a start date.' : null,
              forceErrorText: _serverErrors['valid_from'],
              decoration: const InputDecoration(labelText: 'Valid from', suffixIcon: Icon(Icons.calendar_today)),
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
                    ? const Icon(Icons.calendar_today)
                    : IconButton(
                  icon: const Icon(Icons.close),
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
              : const Text('Create'),
        ),
      ],
    );
  }
}