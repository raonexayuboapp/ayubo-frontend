import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/money.dart';
import '../utils/receipt_download.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import 'order_detail_screen.dart';
import 'payment_screen.dart';

typedef OrderData = Map<String, dynamic>;

class OrderPlacedScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> user;
  const OrderPlacedScreen({super.key, required this.order, required this.user});

  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  late OrderData _order = widget.order;

  bool get _paid => _order['payment_status'] == 'paid';

  Future<void> _pay() async {
    final updated = await Navigator.push<OrderData>(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(order: _order, user: widget.user)),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _order = updated);
    } else {
      // Re-fetch the order from API in case payment completed or status updated
      try {
        final fresh = await ApiService.instance.getOrder(_order['id'] as int);
        if (mounted) setState(() => _order = fresh);
      } catch (_) {}
    }
  }

  void _openOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: _order['id'] as int,
          number: _order['number'] as String,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    final total = ((_order['totals'] as Map<String, dynamic>)['total_cents'] as num).toInt();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppBottomBar.open(context, 0, widget.user);
      },
      child: Scaffold(
        appBar: AppHeader(
          title: _paid ? (l10n?.orderPaid ?? 'Order Paid') : (l10n?.orderPlaced ?? 'Order Placed'),
          subtitle: isDe ? 'Bestellung erfolgreich eingegangen' : 'Thank you for your order',
          user: widget.user,
          showBackButton: false,
        ),
        body: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (_paid ? Colors.green.shade600 : goldColor).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _paid ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded,
                    size: 64,
                    color: _paid ? Colors.green.shade600 : goldColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _paid
                    ? (l10n?.thankYouOrder ?? 'Thank you for your order!')
                    : (isDe ? 'Ihre Bestellung ist eingegangen' : 'Your order is placed'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isDe ? 'Bestellung ${_order['number']}' : 'Order ${_order['number']}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCents(total),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _paid
                      ? (l10n?.orderConfirmedMessage ??
                          'Your payment is complete. You will get an email, and you can download your receipt from the order.')
                      : (l10n?.orderPendingPaymentMessage ??
                          'Your items are reserved for a short time. Pay now to complete your order.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              if (!_paid) ...[
                ElevatedButton.icon(
                  onPressed: _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: goldColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.payment, size: 20),
                  label: Text(l10n?.payNow ?? 'Pay now', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _openOrder,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: goldColor),
                    foregroundColor: goldColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(l10n?.viewOrder ?? 'View order', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _openOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: goldColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(l10n?.viewOrder ?? 'View order', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => downloadReceipt(context, _order['id'] as int, _order['number'] as String),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: goldColor),
                    foregroundColor: goldColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_outlined, size: 20),
                  label: Text(l10n?.receiptPdf ?? 'Download Receipt (PDF)', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => AppBottomBar.open(context, 1, widget.user),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                child: Text(l10n?.continueShopping ?? 'Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
