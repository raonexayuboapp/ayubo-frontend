import 'package:flutter/material.dart';

import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import 'order_detail_screen.dart';
import 'payment_screen.dart';

class OrderPlacedScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> user;
  const OrderPlacedScreen({super.key, required this.order, required this.user});

  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  late Map<String, dynamic> _order = widget.order;

  bool get _paid => _order['payment_status'] == 'paid';

  Future<void> _pay() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(order: _order, user: widget.user)),
    );
    if (updated != null && mounted) setState(() => _order = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = ((_order['totals'] as Map<String, dynamic>)['total_cents'] as num).toInt();

    // Back must not return to the old cart screen underneath: it goes to Home.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppBottomBar.open(context, 0, widget.user);
      },
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(_paid ? 'Order paid' : 'Order placed')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Icon(_paid ? Icons.check_circle_outline : Icons.hourglass_top_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(_paid ? 'Thank you for your order!' : 'Your order is placed', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Order ${_order['number']}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            Text(formatCents(total), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              _paid
                  ? 'Your payment is complete. You will get an email, and you can download your receipt from the order.'
                  : 'Your items are reserved for a short time. Pay now to complete your order.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!_paid) ...[
              FilledButton.icon(onPressed: _pay, icon: const Icon(Icons.payment), label: const Text('Pay now')),
              const SizedBox(height: 8),
            ],
            if (_paid) ...[
              FilledButton(onPressed: () => _openOrder(), child: const Text('View order')),
              const SizedBox(height: 8),
            ] else
              OutlinedButton(onPressed: () => _openOrder(), child: const Text('View order')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => AppBottomBar.open(context, 1, widget.user),
              child: const Text('Continue shopping'),
            ),
          ],
        ),
      ),
    );
  }

  void _openOrder() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrderDetailScreen(orderId: _order['id'] as int, number: _order['number'] as String, user: widget.user),
    ),
  );
}