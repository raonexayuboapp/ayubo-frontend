import 'package:flutter/material.dart';

import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import 'order_detail_screen.dart';

class OrderPlacedScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> user;
  const OrderPlacedScreen({super.key, required this.order, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = (order['totals'] as Map<String, dynamic>)['total_cents'] as int;
    final unpaid = order['payment_status'] == 'unpaid';

    // Back must not return to the old cart screen underneath: it goes to Home.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppBottomBar.open(context, 0, user);
      },
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Order placed')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Icon(Icons.check_circle_outline, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Thank you for your order!', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Order ${order['number']}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            Text(formatCents(total), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (unpaid)
            // ASSUMPTION for now: payment arrives with the next backend part. Replace this text with the pay button then.
              Text('Your items are reserved for you. Online payment is not available yet.',
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'] as int, number: order['number'] as String)),
              ),
              child: const Text('View order'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => AppBottomBar.open(context, 1, user),
              child: const Text('Continue shopping'),
            ),
          ],
        ),
      ),
    );
  }
}