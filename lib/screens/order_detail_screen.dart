import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/address_text.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/product_image.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String? number; // shown in the app bar while the order loads
  const OrderDetailScreen({super.key, required this.orderId, this.number});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      if (_order != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
                title: Text((p['provider'] as String).replaceAll('_', ' ')),
                subtitle: Text([
                  paymentStatusLabel(p['status'] as String),
                  if (p['paid_at'] != null) formatDateTime(p['paid_at'] as String?),
                ].join(' · ')),
                trailing: Text(formatCents(p['amount_cents'] as int)),
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