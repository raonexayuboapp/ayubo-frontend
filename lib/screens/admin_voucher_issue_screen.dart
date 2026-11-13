import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';
import '../widgets/loading_button.dart';

/// Issues vouchers to a customer. The customer finds them in their account and is emailed the codes. Staff never see
/// a code: they do not need one, and a code staff can see is a code that can be misused.
class AdminVoucherIssueScreen extends StatefulWidget {
  const AdminVoucherIssueScreen({super.key});

  @override
  State<AdminVoucherIssueScreen> createState() =>
      _AdminVoucherIssueScreenState();
}

class _AdminVoucherIssueScreenState extends State<AdminVoucherIssueScreen> {
  static const _minCents = 100; // the server's limits: 1.00 to 10,000.00
  static const _maxCents = 1000000;

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _value = TextEditingController(text: '25');
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  final String _key = newRequestKey(
    24,
  ); // one key for this form: a repeated request is never issued twice

  String _expiry = 'default'; // default | date | never
  DateTime? _date;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  List<Map<String, dynamic>>? _issued;
  String _owner = '';

  @override
  void dispose() {
    for (final c in [_email, _value, _quantity, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _vEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter the customer\'s email address.';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) && s.length <= 190
        ? null
        : 'Enter a valid email address.';
  }

  String? _vValue(String? v) {
    final cents = parseEuroToCents((v ?? '').trim());
    if (cents == null) return 'Enter an amount like 25 or 12.50.';
    return cents < _minCents || cents > _maxCents
        ? 'The value must be from €1.00 to €10,000.00.'
        : null;
  }

  String? _vQuantity(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 1 || n > 100
        ? 'Enter a whole number from 1 to 100.'
        : null;
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

  Future<void> _issue() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;
    if (_expiry == 'date' && _date == null) {
      setState(
        () => _error = 'Pick the expiry date, or choose another expiry.',
      );
      return;
    }

    setState(() => _saving = true);

    final quantity = int.parse(_quantity.text.trim());
    final body = <String, dynamic>{
      'request_key': _key,
      'owner_email': _email.text.trim(),
      'value_cents': parseEuroToCents(
        _value.text.trim(),
      )!, // safe: validate() accepted it
      if (quantity > 1) 'quantity': quantity,
      if (_expiry == 'never') 'expires_at': null,
      if (_expiry == 'date')
        'expires_at': _date!.toIso8601String().substring(0, 10),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };

    try {
      final vouchers = await ApiService.instance.adminIssueVouchers(body);
      if (!mounted) return;
      setState(() {
        _issued = vouchers;
        _owner = _email.text.trim();
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

  Widget _done() {
    final theme = Theme.of(context);
    final issued = _issued!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          '${issued.length} voucher${issued.length == 1 ? '' : 's'} issued',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'They are in $_owner\'s account, and the customer is emailed the codes. You do not see the codes.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        for (final v in issued)
          ListTile(
            key: ValueKey(v['id']),
            dense: true,
            leading: const Icon(Icons.card_giftcard_outlined),
            title: Text(
              '•••• ${v['suffix']}  ·  ${formatCents((v['value_cents'] as num).toInt())}',
            ),
            subtitle: Text(
              v['expires_at'] == null
                  ? 'no expiry'
                  : 'valid until ${formatDate(v['expires_at'] as String?)}',
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _formView() {
    final theme = Theme.of(context);

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _email,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vEmail,
            forceErrorText: _serverErrors['owner_email'],
            decoration: const InputDecoration(
              labelText: 'Customer email',
              helperText:
                  'The customer receives the vouchers in their account and by email.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _value,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _vValue,
                  forceErrorText: _serverErrors['value_cents'],
                  decoration: const InputDecoration(
                    labelText: 'Value of each voucher (€)',
                  ),
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
            ],
          ),
          const SizedBox(height: 20),
          Text('Expiry', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Shop default'),
                selected: _expiry == 'default',
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _expiry = 'default'),
              ),
              ChoiceChip(
                label: const Text('A date'),
                selected: _expiry == 'date',
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _expiry = 'date'),
              ),
              ChoiceChip(
                label: const Text('Never expires'),
                selected: _expiry == 'never',
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _expiry = 'never'),
              ),
            ],
          ),
          if (_expiry == 'date')
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                _date == null
                    ? 'Pick a date'
                    : 'Valid until ${_date!.toIso8601String().substring(0, 10)}',
              ),
              onTap: _saving ? null : _pickDate,
            ),
          if (_serverErrors['expires_at'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _serverErrors['expires_at']!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _note,
            enabled: !_saving,
            maxLength: 200,
            forceErrorText: _serverErrors['note'],
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              helperText: 'For example: apology for the late delivery',
            ),
          ),
          if (_serverErrors['request_key'] != null)
            Text(
              _serverErrors['request_key']!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          LoadingButton(
            label: 'Issue vouchers',
            loading: _saving,
            onPressed: _issue,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_issued == null ? 'Issue vouchers' : 'Vouchers issued'),
      ),
      body: _issued == null ? _formView() : _done(),
    );
  }
}
