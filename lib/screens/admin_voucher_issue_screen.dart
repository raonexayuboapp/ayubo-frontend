import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';
import '../widgets/loading_button.dart';

/// Issues vouchers. The plain codes exist only in the server's answer, so after success this screen shows them
/// once and asks for confirmation before it lets go of them.
class AdminVoucherIssueScreen extends StatefulWidget {
  const AdminVoucherIssueScreen({super.key});

  @override
  State<AdminVoucherIssueScreen> createState() => _AdminVoucherIssueScreenState();
}

class _AdminVoucherIssueScreenState extends State<AdminVoucherIssueScreen> {
  static const _minCents = 100; // the server's limits: 1.00 to 10,000.00
  static const _maxCents = 1000000;

  final _form = GlobalKey<FormState>();
  final _value = TextEditingController(text: '25');
  final _quantity = TextEditingController(text: '1');
  final _email = TextEditingController();
  final _note = TextEditingController();
  final String _key = newRequestKey(24); // one key for this form: a repeated request is never issued twice

  String _expiry = 'default'; // default | date | never
  DateTime? _date;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  List<Map<String, dynamic>>? _issued;
  bool _copied = false;

  @override
  void dispose() {
    for (final c in [_value, _quantity, _email, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- validation (the server checks everything again) ----------

  String? _vValue(String? v) {
    final cents = parseEuroToCents((v ?? '').trim());
    if (cents == null) return 'Enter an amount like 25 or 12.50.';
    return cents < _minCents || cents > _maxCents ? 'The value must be from €1.00 to €10,000.00.' : null;
  }

  String? _vQuantity(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 1 || n > 100 ? 'Enter a whole number from 1 to 100.' : null;
  }

  String? _vEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) && s.length <= 190 ? null : 'Enter a valid email address, or leave it empty.';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(2100),
      helpText: 'Valid until the end of this day',
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ---------- issue ----------

  Future<void> _issue() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;
    if (_expiry == 'date' && _date == null) {
      setState(() => _error = 'Pick the expiry date, or choose another expiry.');
      return;
    }

    setState(() => _saving = true);

    final quantity = int.parse(_quantity.text.trim());
    final body = <String, dynamic>{
      'request_key': _key,
      'value_cents': parseEuroToCents(_value.text.trim())!, // safe: validate() accepted it
      if (quantity > 1) 'quantity': quantity,
      if (_expiry == 'never') 'expires_at': null,
      if (_expiry == 'date') 'expires_at': _date!.toIso8601String().substring(0, 10),
      if (_email.text.trim().isNotEmpty) 'owner_email': _email.text.trim(),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };

    try {
      final vouchers = await ApiService.instance.adminIssueVouchers(body);
      if (!mounted) return;
      setState(() {
        _issued = vouchers;
        _saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final errs = e.fieldErrors;
      setState(() {
        _serverErrors = errs;
        _error = errs.isEmpty ? e.message : null;
        _saving = false;
      });
    }
  }

  // ---------- the codes ----------

  Future<void> _copyAll() async {
    final text = _issued!.map((v) => v['code'] as String).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codes copied.')));
  }

  Future<void> _done() async {
    if (!_copied) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Leave without copying?'),
          content: const Text('The codes are shown only this once and cannot be found again. '
              'If you lose them you must cancel these vouchers and issue new ones.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  Widget _codes() {
    final theme = Theme.of(context);
    final issued = _issued!;
    final owner = _email.text.trim();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          color: theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'These codes are shown only once. Copy them now.'
              '${owner.isEmpty ? '' : '\n$owner was also emailed the codes and the vouchers are in their account.'}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final v in issued)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(v['code'] as String,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text([
                formatCents((v['value_cents'] as num).toInt()),
                v['expires_at'] == null ? 'no expiry' : 'valid until ${formatDate(v['expires_at'] as String?)}',
              ].join(' · ')),
            ]),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _copyAll, icon: const Icon(Icons.copy), label: Text('Copy all ${issued.length} code${issued.length == 1 ? '' : 's'}')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _done, child: const Text('Done')),
      ],
    );
  }

  // ---------- the form ----------

  Widget _formView() {
    final theme = Theme.of(context);

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _value,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vValue,
                forceErrorText: _serverErrors['value_cents'],
                decoration: const InputDecoration(labelText: 'Value of each voucher (€)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _quantity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vQuantity,
                forceErrorText: _serverErrors['quantity'],
                decoration: const InputDecoration(labelText: 'How many'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Expiry', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Shop default'), selected: _expiry == 'default', onSelected: _saving ? null : (_) => setState(() => _expiry = 'default')),
            ChoiceChip(label: const Text('A date'), selected: _expiry == 'date', onSelected: _saving ? null : (_) => setState(() => _expiry = 'date')),
            ChoiceChip(label: const Text('Never expires'), selected: _expiry == 'never', onSelected: _saving ? null : (_) => setState(() => _expiry = 'never')),
          ]),
          if (_expiry == 'date')
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_date == null ? 'Pick a date' : 'Valid until ${_date!.toIso8601String().substring(0, 10)}'),
              onTap: _saving ? null : _pickDate,
            ),
          if (_serverErrors['expires_at'] != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(_serverErrors['expires_at']!, style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vEmail,
            forceErrorText: _serverErrors['owner_email'],
            decoration: const InputDecoration(
              labelText: 'Give to a customer (optional)',
              helperText: 'Their email address. The vouchers go to their account and they are emailed the codes. Leave empty to hand the codes over yourself.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            enabled: !_saving,
            maxLength: 200,
            forceErrorText: _serverErrors['note'],
            decoration: const InputDecoration(labelText: 'Note (optional)', helperText: 'For example: apology for the late delivery'),
          ),
          if (_serverErrors['request_key'] != null)
            Text(_serverErrors['request_key']!, style: TextStyle(color: theme.colorScheme.error)),
          if (_error != null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 16),
          LoadingButton(label: 'Issue vouchers', loading: _saving, onPressed: _issue),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Once the codes are on screen, leaving goes through "Done" so they cannot be lost by accident.
    return PopScope(
      canPop: _issued == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _issued != null) _done();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_issued == null ? 'Issue vouchers' : 'Voucher codes')),
        body: _issued == null ? _formView() : _codes(),
      ),
    );
  }
}