import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_header.dart';

typedef PaymentData = Map<String, dynamic>;

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
  PaymentData? _data; // {payment, action}
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

  /// Development payment flow trigger
  Future<void> _dev(String pathKey, {required bool succeeds}) async {
    if (_busy) return;
    final action = _data!['action'] as PaymentData;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await ApiService.instance.devPayment(action[pathKey] as String);
      if (!mounted) return;

      if (succeeds) {
        Navigator.pop(context, order);
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The payment failed. You can try again.')),
      );
      await _start();
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
    final goldColor = theme.colorScheme.secondary;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    }

    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    }

    final payment = _data!['payment'] as PaymentData;
    final action = _data!['action'] as PaymentData;
    final amount = (payment['amount_cents'] as num).toInt();
    final orderTotal = ((widget.order['totals'] as Map<String, dynamic>)['total_cents'] as num).toInt();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Order ${widget.order['number']}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatCents(amount),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: goldColor,
          ),
        ),
        if (amount < orderTotal)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'The remaining ${formatCents(orderTotal - amount)} was covered using your membership credit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (action['type'] == 'dev_confirm') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: goldColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.developer_mode, color: goldColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Development mode sandbox. No real transaction takes place.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : () => _dev('confirm_path', succeeds: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: goldColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _busy
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: goldColor))
                : Text('Pay ${formatCents(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : () => _dev('fail_path', succeeds: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simulate a failed payment'),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'This payment gateway mode is not supported in the mobile client yet. Please try again after updating.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Your items stay reserved for a short time. If you leave now, you can complete the payment later from My Orders.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppHeader(
          title: 'Payment',
          subtitle: 'Order #${widget.order['id']}',
          user: widget.user,
          showBackButton: !_busy,
        ),
        body: _content(),
      ),
    );
  }
}