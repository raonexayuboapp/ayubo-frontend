import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/product_image.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const OrdersScreen({super.key, required this.user});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.listOrders(page: _page);
      final list = (data['orders'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _orders = reset ? list : [..._orders, ...list];
        _total = (data['meta'] as Map<String, dynamic>)['total'] as int;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (reset) {
          _error = e.message;
        } else {
          _page--; // let "Load more" try the same page again
        }
      });
      if (!reset) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(Map<String, dynamic> o) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: o['id'] as int, number: o['number'] as String, user: widget.user),
      ),
    );
    if (mounted) _load(reset: true); // the status may have moved while the customer looked at it
  }

  Widget _card(Map<String, dynamic> o) {
    final theme = Theme.of(context);
    final preview = (o['preview'] as List<dynamic>).cast<String>();
    final count = o['item_count'] as int;

    return Card(
      key: ValueKey(o['id']),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(o),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ProductImage(url: o['image_url'] as String?)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['number'] as String, style: theme.textTheme.titleSmall),
                Text(formatDate(o['created_at'] as String?), style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  preview.join(', ') + (count > preview.length ? ' …' : ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  OrderStatusChip(status: o['status'] as String),
                  OrderStatusChip(status: o['payment_status'] as String, payment: true),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatCents(o['total_cents'] as int), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text('$count item${count == 1 ? '' : 's'}', style: theme.textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _orders.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else if (_orders.isEmpty) {
      // A scrollable, so pull-to-refresh still works on an empty list.
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(children: [
          const SizedBox(height: 140),
          const Center(child: Text('You have not placed an order yet.')),
          const SizedBox(height: 16),
          Center(child: FilledButton(onPressed: () => AppBottomBar.open(context, 1, widget.user), child: const Text('Browse products'))),
        ]),
      );
    } else {
      final hasMore = _orders.length < _total;
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _orders.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _orders.length) {
              return TextButton(
                onPressed: _loading
                    ? null
                    : () {
                  _page++;
                  _load(reset: false);
                },
                child: const Text('Load more'),
              );
            }
            return _card(_orders[i]);
          },
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: Text('My orders ($_total)')), body: body);
  }
}