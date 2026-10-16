import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

/// Every stock movement of one variant, newest first.
class AdminStockHistoryScreen extends StatefulWidget {
  final int variantId;
  final String title;
  const AdminStockHistoryScreen({super.key, required this.variantId, required this.title});

  @override
  State<AdminStockHistoryScreen> createState() => _AdminStockHistoryScreenState();
}

class _AdminStockHistoryScreenState extends State<AdminStockHistoryScreen> {
  static const _reasons = {
    'receipt': 'Goods received',
    'adjustment': 'Adjustment',
    'stocktake': 'Stocktake',
    'sale': 'Sale',
  };

  List<Map<String, dynamic>> _items = [];
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
      final data = await ApiService.instance.adminStockMovements(widget.variantId, page: _page);
      final list = (data['movements'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
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
          _page--; // let "Load more" try the same page again
        }
      });
      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// The server sends UTC as "2026-10-15 09:30:00". Show it in the device's time zone.
  String _when(String stamp) {
    final d = DateTime.tryParse('${stamp.replaceFirst(' ', 'T')}Z')?.toLocal();
    if (d == null) return stamp;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else if (_items.isEmpty) {
      body = const Center(child: Text('No stock movements yet.'));
    } else {
      final hasMore = _items.length < _total;
      body = ListView.builder(
        itemCount: _items.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _items.length) {
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

          final m = _items[i];
          final delta = m['delta'] as num;
          final positive = delta > 0;
          final reason = m['reason'] as String;

          return ListTile(
            key: ValueKey(m['id']),
            title: Text(_reasons[reason] ?? reason),
            subtitle: Text([
              '${m['location_code']}',
              _when(m['created_at'] as String),
              if (m['order_item_id'] != null) 'order line ${m['order_item_id']}',
            ].join(' · ')),
            trailing: Text(
              '${positive ? '+' : ''}${formatQuantity(delta)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: positive ? Colors.green.shade700 : theme.colorScheme.error,
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('History · ${widget.title}')),
      body: body,
    );
  }
}