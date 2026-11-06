import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/address_text.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/receipt_download.dart';
import '../widgets/app_header.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/product_image.dart';
import 'payment_screen.dart';

typedef OrderData = Map<String, dynamic>;

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String? number;
  final Map<String, dynamic> user;
  const OrderDetailScreen({super.key, required this.orderId, required this.user, this.number});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderData? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _payable => _order?['status'] == 'received' && _order?['payment_status'] == 'unpaid';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    setState(() {
      _loading = _order == null;
      _error = null;
    });
    try {
      final order = await ApiService.instance.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_order == null) _error = e.message;
      });
      if (_order != null) _snack(e.message);
    }
  }

  Future<void> _pay() async {
    final updated = await Navigator.push<OrderData>(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(order: _order!, user: widget.user)),
    );
    if (updated != null && mounted) setState(() => _order = updated);
  }

  Future<void> _cancel() async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n?.cancelOrderConfirmTitle ?? 'Cancel this order?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n?.cancelOrderConfirmMessage ??
              'Your reserved items are released and any membership credit used is given back. This cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n?.keepOrder ?? 'Keep order',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n?.cancelOrder ?? 'Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final order = await ApiService.instance.cancelOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _order = order);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  Widget _row(String label, String value, {bool bold = false, bool small = false}) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : (small
            ? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))
            : theme.textTheme.bodyMedium);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  List<Widget> _items(List<OrderData> items) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    return [
      for (final i in items)
        Container(
          key: ValueKey(i['id']),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ProductImage(url: i['image_url'] as String?),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i['name'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${formatQuantity(i['quantity'] as num)} × ${formatCents(i['unit_price_cents'] as int)}',
                        if ((i['discount_cents'] as int) > 0)
                          (isDe
                              ? 'Rabatt −${formatCents(i['discount_cents'] as int)}'
                              : 'discount −${formatCents(i['discount_cents'] as int)}'),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCents(i['line_total_cents'] as int),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _totals(OrderData totals, bool hasShipping) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    final discount = totals['discount_cents'] as int;
    final shipping = totals['shipping_cents'] as int;
    final tax = (totals['tax'] as List<dynamic>).cast<OrderData>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _row(isDe ? 'Artikel' : 'Items', formatCents(totals['subtotal_cents'] as int)),
          if (discount > 0) _row(isDe ? 'Rabatt' : 'Discount', '−${formatCents(discount)}'),
          if (hasShipping)
            _row(l10n?.shipping ?? 'Shipping', shipping == 0 ? (l10n?.shippingFree ?? 'Free') : formatCents(shipping)),
          Divider(height: 20, color: theme.dividerColor.withValues(alpha: 0.15)),
          _row(l10n?.total ?? 'Total', formatCents(totals['total_cents'] as int), bold: true),
          const SizedBox(height: 4),
          for (final t in tax)
            _row(
              isDe
                  ? 'inkl. ${formatPercent(t['rate_percent'] as num)}% MwSt. (netto ${formatCents(t['net_cents'] as int)})'
                  : 'incl. ${formatPercent(t['rate_percent'] as num)}% VAT (net ${formatCents(t['net_cents'] as int)})',
              formatCents(t['tax_cents'] as int),
              small: true,
            ),
        ],
      ),
    );
  }

  Widget _addressCard(String title, OrderData address) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            addressLines(address).join('\n'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _providerLabel(String provider) {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    return switch (provider) {
      'membership_credit' => isDe ? 'Mitgliedschaftsguthaben' : 'Membership credit',
      'gift_voucher' => isDe ? 'Geschenkgutschein' : 'Gift voucher',
      'manual' => isDe ? 'Banküberweisung / Vor Ort' : 'Bank transfer / in shop',
      'dev' => isDe ? 'Testzahlung' : 'Test payment',
      _ => provider.replaceAll('_', ' '),
    };
  }

  Widget _body() {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n?.retry ?? 'Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    }

    final o = _order!;
    final items = (o['items'] as List<dynamic>).cast<OrderData>();
    final addresses = o['addresses'] as OrderData;
    final shipments = (o['shipments'] as List<dynamic>).cast<OrderData>();
    final payments = (o['payments'] as List<dynamic>).cast<OrderData>();
    final refunds = ((o['refunds'] as List<dynamic>?) ?? const []).cast<OrderData>();
    final history = (o['history'] as List<dynamic>).cast<OrderData>();

    return RefreshIndicator(
      onRefresh: _load,
      color: goldColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            o['number'] as String,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            isDe
                ? 'Aufgegeben am ${formatDateTime(o['created_at'] as String?)}'
                : 'Placed ${formatDateTime(o['created_at'] as String?)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OrderStatusChip(status: o['status'] as String),
              OrderStatusChip(status: o['payment_status'] as String, payment: true),
            ],
          ),
          if (o['status'] == 'on_hold')
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: goldColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                isDe
                    ? 'Ihre Bestellung ist bezahlt und wird von uns geprüft. Wir melden uns, falls wir noch Angaben benötigen.'
                    : 'Your order is paid and we are checking it. We will get in touch if we need anything from you.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_payable)
                ElevatedButton.icon(
                  onPressed: _busy ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: goldColor,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text(l10n?.payNow ?? 'Pay now', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => downloadReceipt(context, widget.orderId, o['number'] as String),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: goldColor),
                  foregroundColor: goldColor,
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n?.receiptPdf ?? 'Receipt (PDF)'),
              ),
              if (_payable)
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: Text(l10n?.cancelOrder ?? 'Cancel order'),
                ),
            ],
          ),
          _heading(isDe ? 'Artikel' : 'Items'),
          ..._items(items),
          _heading(l10n?.total ?? 'Total'),
          _totals(o['totals'] as OrderData, addresses['shipping'] != null),
          if (addresses.isNotEmpty) _heading(isDe ? 'Adressen' : 'Addresses'),
          if (addresses['shipping'] != null)
            _addressCard(l10n?.shippingAddress ?? 'Delivery address', addresses['shipping'] as OrderData),
          if (addresses['billing'] != null)
            _addressCard(l10n?.billingAddress ?? 'Billing address', addresses['billing'] as OrderData),
          if (shipments.isNotEmpty) ...[
            _heading(l10n?.shipping ?? 'Shipping'),
            for (final s in shipments)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: ListTile(
                  leading: Icon(Icons.local_shipping_outlined, color: goldColor),
                  title: Text((s['carrier'] as String?) ?? (isDe ? 'Paket' : 'Parcel')),
                  subtitle: SelectableText(
                    [
                      if (s['tracking_number'] != null)
                        (isDe
                            ? 'Sendungsnummer ${s['tracking_number']}'
                            : 'Tracking number ${s['tracking_number']}'),
                      orderStatusLabel(s['status'] as String),
                      if (s['shipped_at'] != null)
                        (isDe
                            ? 'versandt ${formatDate(s['shipped_at'] as String?)}'
                            : 'shipped ${formatDate(s['shipped_at'] as String?)}'),
                      if (s['delivered_at'] != null)
                        (isDe
                            ? 'zugestellt ${formatDate(s['delivered_at'] as String?)}'
                            : 'delivered ${formatDate(s['delivered_at'] as String?)}'),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
          if (payments.isNotEmpty) ...[
            _heading(isDe ? 'Zahlungen' : 'Payments'),
            for (final p in payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _providerLabel(p['provider'] as String),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            [
                              paymentStatusLabel(p['status'] as String),
                              if (p['paid_at'] != null) formatDateTime(p['paid_at'] as String?),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCents(p['amount_cents'] as int),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
          if (refunds.isNotEmpty) ...[
            _heading(isDe ? 'Erstattungen' : 'Refunds'),
            for (final r in refunds)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.undo_outlined, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['provider'] == 'membership_credit'
                                ? (isDe ? 'Als Mitgliedschaftsguthaben erstattet' : 'Returned as membership credit')
                                : (isDe ? 'Erstattet' : 'Refunded'),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            formatDate(r['created_at'] as String?),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '−${formatCents(r['amount_cents'] as int)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          _heading(l10n?.orderStatus ?? 'Status'),
          for (final h in history.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: goldColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      orderStatusLabel(h['status'] as String),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    formatDateTime(h['created_at'] as String?),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: widget.number != null ? 'Order #${widget.number}' : (l10n?.orderDetails ?? 'Order Details'),
        subtitle: isDe ? 'Bestelldetails & Status' : 'Order status & items',
        user: widget.user,
        showBackButton: true,
      ),
      body: _body(),
    );
  }
}
