import 'package:flutter/material.dart';

// ASSUMPTION: these are the status words the backend uses. Confirm them with the supervisor.
String orderStatusLabel(String status) => switch (status) {
  'received' => 'Received',
  'processing' => 'Processing',
  'shipped' => 'Shipped',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status.replaceAll('_', ' '),
};

String paymentStatusLabel(String status) => switch (status) {
  'unpaid' => 'Awaiting payment',
  'paid' => 'Paid',
  'refunded' => 'Refunded',
  'partially_refunded' => 'Partly refunded',
  _ => status.replaceAll('_', ' '),
};

/// A small coloured pill for an order status or a payment status.
class OrderStatusChip extends StatelessWidget {
  final String status;
  final bool payment; // true for the payment status, false for the order status
  const OrderStatusChip({super.key, required this.status, this.payment = false});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    final (background, foreground) = switch (status) {
      'delivered' || 'paid' => (s.primaryContainer, s.onPrimaryContainer),
      'shipped' || 'processing' => (s.secondaryContainer, s.onSecondaryContainer),
      'cancelled' || 'refunded' => (s.errorContainer, s.onErrorContainer),
      _ => (s.surfaceContainerHighest, s.onSurface), // received, unpaid, partly refunded
    };

    return Chip(
      label: Text(payment ? paymentStatusLabel(status) : orderStatusLabel(status),
          style: TextStyle(fontSize: 12, color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}