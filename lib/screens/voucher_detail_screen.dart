import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/voucher_state_chip.dart';

class VoucherDetailScreen extends StatefulWidget {
  final int voucherId;
  const VoucherDetailScreen({super.key, required this.voucherId});

  @override
  State<VoucherDetailScreen> createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends State<VoucherDetailScreen> {
  Map<String, dynamic>? _voucher;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _voucher == null;
      _error = null;
    });
    try {
      final voucher = await ApiService.instance.getVoucher(widget.voucherId);
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
      if (_voucher != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _label(String type, String? order) {
    switch (type) {
      case 'issue':
        return 'Added';
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
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value)]),
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
    final isCredit = v['kind'] == 'membership_credit';
    final expires = v['expires_at'] as String?;
    final transactions = (v['transactions'] as List<dynamic>).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(isCredit ? 'Membership credit' : 'Gift voucher •••• ${v['suffix']}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(formatCents(v['balance_cents'] as int),
                    style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('remaining balance', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                VoucherStateChip(state: v['state'] as String),
                const Divider(height: 28),
                _info('Original value', formatCents(v['original_cents'] as int)),
                _info('Valid until', expires == null ? 'No expiry' : formatDate(expires)),
                _info('Added', formatDate(v['created_at'] as String?)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isCredit
                ? 'This credit is used automatically when you choose "Pay with my membership" at checkout.'
                : 'The voucher code was emailed to you when you ordered. For your security it is never shown again.',
            style: theme.textTheme.bodySmall,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text('History', style: theme.textTheme.titleMedium),
          ),
          if (transactions.isEmpty) const Text('Nothing has happened with this voucher yet.'),
          for (final t in transactions) _transaction(t),
        ],
      ),
    );
  }

  Widget _transaction(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final amount = t['amount_cents'] as int;
    final positive = amount > 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(_label(t['type'] as String, t['order_number'] as String?)),
      subtitle: Text(formatDateTime(t['created_at'] as String?)),
      trailing: Text(
        '${positive ? '+' : '−'}${formatCents(amount.abs())}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: positive ? Colors.green.shade700 : theme.colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Voucher')), body: _body());
  }
}