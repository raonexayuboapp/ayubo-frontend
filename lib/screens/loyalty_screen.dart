import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  List<Map<String, dynamic>> _items = [];
  int _balance = 0;
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
      final data = await ApiService.instance.loyalty(page: _page);
      final list = (data['transactions'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num).toInt();
        _items = reset ? list : [..._items, ...list];
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
          _page--;
        }
      });
      if (!reset) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _label(String type) {
    switch (type) {
      case 'earn':
        return 'Points earned';
      case 'reverse':
        return 'Points taken back (refund)';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Widget _header() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.stars_outlined, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text('$_balance', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          Text('points', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Text('You earn points on the money you pay for an order. Points are added when the order is paid.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final points = t['points'] as int;
    final positive = points > 0;
    final order = t['order_number'] as String?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(_label(t['type'] as String)),
      subtitle: Text([if (order != null) 'Order $order', formatDate(t['created_at'] as String?)].join(' · ')),
      trailing: Text(
        '${positive ? '+' : '−'}${points.abs()}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: positive ? Colors.green.shade700 : theme.colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _items.isEmpty && _total == 0 && _balance == 0) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else {
      final hasMore = _items.length < _total;
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            const Padding(padding: EdgeInsets.only(top: 24, bottom: 8), child: Text('History')),
            if (_items.isEmpty) const Text('No points yet. Your first order will earn some.'),
            for (final t in _items) _row(t),
            if (hasMore)
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                  _page++;
                  _load(reset: false);
                },
                child: const Text('Load more'),
              ),
          ],
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('My points')), body: body);
  }
}