import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/order_status_chip.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  // "on_hold" first: those orders are paid and need a person.
  static const _statuses = [
    '',
    'on_hold',
    'received',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
  ];
  static const _payments = [
    '',
    'unpaid',
    'paid',
    'partially_refunded',
    'refunded',
  ];

  final _search = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _orders = [];
  String _status = '';
  String _payment = '';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;
  int _request = 0; // an answer that belongs to an older search is ignored

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final request = ++_request;
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.adminListOrders(
        status: _status,
        paymentStatus: _payment,
        search: _search.text.trim(),
        page: _page,
      );
      if (!mounted || request != _request) return;

      final list = (data['orders'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      setState(() {
        _orders = reset ? list : [..._orders, ...list];
        _total = (data['meta'] as Map<String, dynamic>)['total'] as int;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        if (reset) {
          _error = e.message;
        } else {
          _page--; // let "Load more" try the same page again
        }
      });
      if (!reset)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onSearchChanged(String _) {
    setState(() {}); // shows or hides the clear button
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(reset: true),
    );
  }

  Future<void> _open(Map<String, dynamic> o) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailScreen(
          orderId: o['id'] as int,
          number: o['number'] as String,
        ),
      ),
    );
    if (mounted) _load(reset: true); // the order may have moved on
  }

  Widget _chips(
    List<String> values,
    String selected,
    String Function(String) label,
    ValueChanged<String> onSelected,
  ) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(v.isEmpty ? 'All' : label(v)),
                selected: selected == v,
                onSelected: (_) => onSelected(v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final theme = Theme.of(context);
    final customer = o['customer'] as Map<String, dynamic>;
    final needsAttention = o['status'] == 'on_hold';
    final count = o['item_count'] as int;

    return Card(
      key: ValueKey(o['id']),
      shape: needsAttention
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.error, width: 1.5),
            )
          : null,
      child: ListTile(
        onTap: () => _open(o),
        leading: Icon(
          needsAttention
              ? Icons.warning_amber_rounded
              : Icons.receipt_long_outlined,
          color: needsAttention ? theme.colorScheme.error : null,
        ),
        title: Text(o['number'] as String),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${customer['name']} · ${formatDate(o['created_at'] as String?)}',
            ),
            Text(customer['email'] as String, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                OrderStatusChip(status: o['status'] as String),
                OrderStatusChip(
                  status: o['payment_status'] as String,
                  payment: true,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCents(o['total_cents'] as int),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$count item${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _orders.isEmpty)
      return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(
              onPressed: () => _load(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Center(child: Text('No orders found.')),
          ],
        ),
      );
    }

    final hasMore = _orders.length < _total;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Orders ($_total)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Order number, customer, email',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                      ),
              ),
            ),
          ),
          _chips(_statuses, _status, orderStatusLabel, (v) {
            setState(() => _status = v);
            _load(reset: true);
          }),
          _chips(_payments, _payment, paymentStatusLabel, (v) {
            setState(() => _payment = v);
            _load(reset: true);
          }),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
