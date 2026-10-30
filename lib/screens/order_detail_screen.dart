import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/address_text.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/receipt_download.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/product_image.dart';
import 'payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String? number; // shown in the app bar while the order loads
  final Map<String, dynamic> user;
  const OrderDetailScreen({super.key, required this.orderId, required this.user, this.number});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// Only an order that has not been paid or cancelled can still be paid or cancelled by the customer.
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
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(order: _order!, user: widget.user)),
    );
    if (updated != null && mounted) setState(() => _order = updated);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('Your reserved items are released and any membership credit used is given back. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order')),
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
      await _load(); // for example it was paid in the meantime
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _row(String label, String value, {bool bold = false, bool small = false}) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : (small ? theme.textTheme.bodySmall : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ]),
    );
  }

  List<Widget> _items(List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);

    return [
      for (final i in items)
        ListTile(
          key: ValueKey(i['id']),
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ProductImage(url: i['image_url'] as String?)),
          ),
          title: Text(i['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text([
            '${formatQuantity(i['quantity'] as num)} × ${formatCents(i['unit_price_cents'] as int)}',
            if ((i['discount_cents'] as int) > 0) 'discount −${formatCents(i['discount_cents'] as int)}',
          ].join(' · ')),
          trailing: Text(formatCents(i['line_total_cents'] as int), style: theme.textTheme.titleSmall),
        ),
    ];
  }

  Widget _totals(Map<String, dynamic> totals, bool hasShipping) {
    final discount = totals['discount_cents'] as int;
    final shipping = totals['shipping_cents'] as int;
    final tax = (totals['tax'] as List<dynamic>).cast<Map<String, dynamic>>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _row('Items', formatCents(totals['subtotal_cents'] as int)),
          if (discount > 0) _row('Discount', '−${formatCents(discount)}'),
          if (hasShipping) _row('Shipping', shipping == 0 ? 'Free' : formatCents(shipping)),
          const Divider(height: 20),
          _row('Total', formatCents(totals['total_cents'] as int), bold: true),
          const SizedBox(height: 4),
          for (final t in tax)
            _row('incl. ${formatPercent(t['rate_percent'] as num)}% VAT (net ${formatCents(t['net_cents'] as int)})',
                formatCents(t['tax_cents'] as int),
                small: true),
        ]),
      ),
    );
  }

  Widget _addressCard(String title, Map<String, dynamic> address) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(addressLines(address).join('\n')),
      ]),
    ),
  );

  String _providerLabel(String provider) => switch (provider) {
    'membership_credit' => 'Membership credit',
    'gift_voucher' => 'Gift voucher',
    'manual' => 'Bank transfer / in the shop',
    'dev' => 'Test payment',
    _ => provider.replaceAll('_', ' '),
  };

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

    final o = _order!;
    final theme = Theme.of(context);
    final items = (o['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    final addresses = o['addresses'] as Map<String, dynamic>;
    final shipments = (o['shipments'] as List<dynamic>).cast<Map<String, dynamic>>();
    final payments = (o['payments'] as List<dynamic>).cast<Map<String, dynamic>>();
    final refunds = ((o['refunds'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
    final history = (o['history'] as List<dynamic>).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(o['number'] as String, style: theme.textTheme.titleLarge),
          Text('Placed ${formatDateTime(o['created_at'] as String?)}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            OrderStatusChip(status: o['status'] as String),
            OrderStatusChip(status: o['payment_status'] as String, payment: true),
          ]),
          if (o['status'] == 'on_hold')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: theme.colorScheme.tertiaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Your order is paid and we are checking it. We will get in touch if we need anything from you.'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (_payable)
              FilledButton.icon(
                onPressed: _busy ? null : _pay,
                icon: const Icon(Icons.payment),
                label: const Text('Pay now'),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => downloadReceipt(context, widget.orderId, o['number'] as String),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Receipt (PDF)'),
            ),
            if (_payable)
              TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel order')),
          ]),
          _heading('Items'),
          ..._items(items),
          _heading('Total'),
          _totals(o['totals'] as Map<String, dynamic>, addresses['shipping'] != null),
          if (addresses.isNotEmpty) _heading('Addresses'),
          if (addresses['shipping'] != null) _addressCard('Delivery address', addresses['shipping'] as Map<String, dynamic>),
          if (addresses['billing'] != null) _addressCard('Billing address', addresses['billing'] as Map<String, dynamic>),
          if (shipments.isNotEmpty) ...[
            _heading('Shipping'),
            for (final s in shipments)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text((s['carrier'] as String?) ?? 'Parcel'),
                  subtitle: SelectableText([
                    if (s['tracking_number'] != null) 'Tracking number ${s['tracking_number']}',
                    orderStatusLabel(s['status'] as String),
                    if (s['shipped_at'] != null) 'shipped ${formatDate(s['shipped_at'] as String?)}',
                    if (s['delivered_at'] != null) 'delivered ${formatDate(s['delivered_at'] as String?)}',
                  ].join(' · ')),
                ),
              ),
          ],
          if (payments.isNotEmpty) ...[
            _heading('Payments'),
            for (final p in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(_providerLabel(p['provider'] as String)),
                subtitle: Text([
                  paymentStatusLabel(p['status'] as String),
                  if (p['paid_at'] != null) formatDateTime(p['paid_at'] as String?),
                ].join(' · ')),
                trailing: Text(formatCents(p['amount_cents'] as int)),
              ),
          ],
          if (refunds.isNotEmpty) ...[
            _heading('Refunds'),
            for (final r in refunds)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.undo_outlined),
                title: Text(r['provider'] == 'membership_credit' ? 'Returned as membership credit' : 'Refunded'),
                subtitle: Text(formatDate(r['created_at'] as String?)),
                trailing: Text('−${formatCents(r['amount_cents'] as int)}'),
              ),
          ],
          _heading('Status'),
          for (final h in history.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(orderStatusLabel(h['status'] as String))),
                Text(formatDateTime(h['created_at'] as String?), style: theme.textTheme.bodySmall),
              ]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.number ?? 'Order')), body: _body());
  }
}