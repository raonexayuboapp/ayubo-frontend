import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/voucher_state_chip.dart';

class AdminVoucherDetailScreen extends StatefulWidget {
  final int voucherId;
  const AdminVoucherDetailScreen({super.key, required this.voucherId});

  @override
  State<AdminVoucherDetailScreen> createState() => _AdminVoucherDetailScreenState();
}

class _AdminVoucherDetailScreenState extends State<AdminVoucherDetailScreen> {
  Map<String, dynamic>? _voucher;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _state => _voucher!['state'] as String;
  String get _kind => _voucher!['kind'] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _voucher == null;
        _error = null;
      });
    }
    try {
      final voucher = await ApiService.instance.adminGetVoucher(widget.voucherId);
      if (!mounted) return;
      setState(() {
        _voucher = voucher;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_voucher == null) _error = e.message;
      });
      if (_voucher != null) _snack(e.message);
    }
  }

  /// Runs an action, shows its message, and reloads either way.
  Future<void> _act(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) _snack(message);
    } on ApiException catch (e) {
      if (mounted) _snack(e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\n') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load(silent: true);
  }

  Future<void> _changeExpiry() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Pick a new expiry date…'),
            subtitle: const Text('An expired voucher works again when the new date is in the future.'),
            onTap: () => Navigator.pop(context, 'date'),
          ),
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: const Text('Remove the expiry'),
            onTap: () => Navigator.pop(context, 'never'),
          ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;

    String? date;
    if (choice == 'date') {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 365)),
        firstDate: now,
        lastDate: DateTime(2100),
        helpText: 'Valid until the end of this day',
      );
      if (picked == null) return;
      date = picked.toIso8601String().substring(0, 10);
    }

    await _act(() async {
      await ApiService.instance.adminSetVoucherExpiry(widget.voucherId, date);
      return date == null ? 'The voucher no longer expires.' : 'The voucher is valid until $date.';
    });
  }

  Future<void> _cancel() async {
    final balance = formatCents(_voucher!['balance_cents'] as int);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this voucher?'),
        content: Text('The remaining balance of $balance is withdrawn and the voucher can no longer be used. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep voucher')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel voucher')),
        ],
      ),
    );
    if (ok != true) return;

    await _act(() async {
      await ApiService.instance.adminCancelVoucher(widget.voucherId);
      return 'The voucher is cancelled.';
    });
  }

  Future<void> _assign() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Voucher to Customer'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the customer\'s registered email address. This voucher will be placed directly in their wallet.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Customer Email',
                  hintText: 'customer@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  final v = val?.trim() ?? '';
                  if (v.isEmpty) return 'Enter a customer email address.';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address.';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, emailController.text.trim());
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;

    await _act(() async {
      await ApiService.instance.adminAssignVoucher(widget.voucherId, email);
      return 'Voucher successfully assigned to $email';
    });
  }

  String _label(String type, String? order) {
    switch (type) {
      case 'issue':
        return 'Issued';
      case 'redeem':
        return order == null ? 'Used' : 'Used for order $order';
      case 'restore':
        return 'Returned (order cancelled)';
      case 'refund':
        return 'Returned (refund)';
      case 'revoke':
        return 'Withdrawn';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ]),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final v = _voucher!;
    final theme = Theme.of(context);
    final owner = v['owner'] as Map<String, dynamic>?;
    final expires = v['expires_at'] as String?;
    final transactions = (v['transactions'] as List<dynamic>).cast<Map<String, dynamic>>();
    final cancelled = _state == 'cancelled';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('•••• ${v['suffix']}', style: theme.textTheme.titleMedium),
                Text(voucherKindLabel(_kind), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(formatCents(v['balance_cents'] as int), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('remaining balance', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                VoucherStateChip(state: _state),
                const Divider(height: 28),
                _info('Original value', formatCents(v['original_cents'] as int)),
                _info('Valid until', expires == null ? 'No expiry' : formatDate(expires)),
                _info('Created', formatDateTime(v['created_at'] as String?)),
                _info('Owner', owner == null ? 'Nobody yet (anyone with the code can add it)' : '${owner['name']}\n${owner['email']}'),
                if (v['order_number'] != null) _info('Bought with order', v['order_number'] as String),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _busy || cancelled || _kind == 'membership_credit' || (v['balance_cents'] as int) <= 0
                  ? null
                  : _assign,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(owner == null ? 'Assign to customer' : 'Reassign customer'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || cancelled ? null : _changeExpiry,
              icon: const Icon(Icons.event),
              label: const Text('Change expiry'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || cancelled || _kind == 'membership_credit' ? null : _cancel,
              icon: const Icon(Icons.block),
              label: const Text('Cancel voucher'),
            ),
          ]),
          if (_kind == 'membership_credit')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Membership credit is managed through the membership, not here.', style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text('History', style: theme.textTheme.titleMedium),
          ),
          for (final t in transactions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_label(t['type'] as String, t['order_number'] as String?)),
              subtitle: Text([
                formatDateTime(t['created_at'] as String?),
                if (t['note'] != null) t['note'] as String,
              ].join(' · ')),
              trailing: Text(
                '${(t['amount_cents'] as int) > 0 ? '+' : '−'}${formatCents((t['amount_cents'] as int).abs())}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: (t['amount_cents'] as int) > 0 ? Colors.green.shade700 : theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Voucher')), body: _body());
  }
}