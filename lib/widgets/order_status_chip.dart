import 'package:flutter/material.dart';
import '../utils/money.dart';

// ASSUMPTION: these are the status words the backend uses. Confirm them with the supervisor.
String orderStatusLabel(String status, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  if (loc.startsWith('de')) {
    return switch (status) {
      'received' => 'Eingegangen',
      'processing' => 'In Bearbeitung',
      'shipped' => 'Versandt',
      'delivered' => 'Zugestellt',
      'cancelled' => 'Storniert',
      'on_hold' => 'In Wartestellung',
      _ => status.replaceAll('_', ' '),
    };
  }
  return switch (status) {
    'received' => 'Received',
    'processing' => 'Processing',
    'shipped' => 'Shipped',
    'delivered' => 'Delivered',
    'cancelled' => 'Cancelled',
    'on_hold' => 'On hold',
    _ => status.replaceAll('_', ' '),
  };
}

String paymentStatusLabel(String status, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  if (loc.startsWith('de')) {
    return switch (status) {
      'unpaid' => 'Zahlung ausstehend',
      'paid' => 'Bezahlt',
      'refunded' => 'Erstattet',
      'partially_refunded' => 'Teilweise erstattet',
      'on_hold' => 'In Wartestellung',
      _ => status.replaceAll('_', ' '),
    };
  }
  return switch (status) {
    'unpaid' => 'Awaiting payment',
    'paid' => 'Paid',
    'refunded' => 'Refunded',
    'partially_refunded' => 'Partly refunded',
    'on_hold' => 'On hold',
    _ => status.replaceAll('_', ' '),
  };
}

/// A small coloured pill for an order status or a payment status.
class OrderStatusChip extends StatelessWidget {
  final String status;
  final bool payment; // true for the payment status, false for the order status
  const OrderStatusChip({super.key, required this.status, this.payment = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final isDark = theme.brightness == Brightness.dark;

    final (background, foreground) = switch (status) {
      'delivered' || 'paid' => (
          Colors.green.shade600.withValues(alpha: isDark ? 0.2 : 0.12),
          isDark ? Colors.green.shade400 : Colors.green.shade700,
        ),
      'shipped' || 'processing' => (
          goldColor.withValues(alpha: 0.15),
          goldColor,
        ),
      'cancelled' || 'refunded' => (
          theme.colorScheme.error.withValues(alpha: 0.12),
          theme.colorScheme.error,
        ),
      _ => (
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: foreground.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        payment ? paymentStatusLabel(status) : orderStatusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
