import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

/// Pays an unpaid order. It starts the payment and shows what the server says to do next.
/// Pops with the updated order when the payment worked, or with nothing when the customer leaves.
class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> user;
  const PaymentScreen({super.key, required this.order, required this.user});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Map<String, dynamic>? _data; // {payment, action}
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.payOrder(widget.order['id'] as int);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// The development payment page: the two buttons stand in for the provider's page.
  Future<void> _dev(String pathKey, {required bool succeeds}) async {
    if (_busy) return;
    final action = _data!['action'] as Map<String, dynamic>;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await ApiService.instance.devPayment(action[pathKey] as String);
      if (!mounted) return;

      if (succeeds) {
        Navigator.pop(context, order); // the customer sees the paid order
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The payment failed. You can try again.')));
      await _start(); // a failed payment is finished: the next try is a new one
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Widget _content() {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _start, child: const Text('Try again')),
          ]),
        ),
      );
    }

    final payment = _data!['payment'] as Map<String, dynamic>;
    final action = _data!['action'] as Map<String, dynamic>;
    final amount = (payment['amount_cents'] as num).toInt();
    final orderTotal = ((widget.order['totals'] as Map<String, dynamic>)['total_cents'] as num).toInt();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Order ${widget.order['number']}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(formatCents(amount), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
        if (amount < orderTotal)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('The other ${formatCents(orderTotal - amount)} was paid with your membership credit.',
                style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 24),
        if (action['type'] == 'dev_confirm') ...[
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Development payment page. No real money is taken. '
                  'The real payment page of the shop\'s payment provider replaces this screen.'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () => _dev('confirm_path', succeeds: true),
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Pay ${formatCents(amount)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _dev('fail_path', succeeds: false),
            child: const Text('Simulate a failed payment'),
          ),
        ] else
          const Text('This way of paying is not supported in the app yet. Please try again after the next update.'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 16),
        Text('Your items stay reserved for a short time. If you leave now you can pay later from My orders.',
            style: theme.textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy, // do not leave while a payment is being confirmed
      child: Scaffold(appBar: AppBar(title: const Text('Payment')), body: _content()),
    );
  }
}