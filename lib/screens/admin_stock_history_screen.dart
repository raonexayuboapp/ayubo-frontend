import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

typedef StockHistoryData = Map<String, dynamic>;

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

  List<StockHistoryData> _items = [];
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
      final list = (data['movements'] as List<dynamic>).cast<StockHistoryData>();
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
    final goldColor = theme.colorScheme.secondary;

    Widget body;

    if (_loading && _items.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    } else if (_error != null) {
      body = Center(
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
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    } else if (_items.isEmpty) {
      body = Center(
        child: Text(
          'No stock movements yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    } else {
      final hasMore = _items.length < _total;
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? CircularProgressIndicator(color: goldColor, strokeWidth: 2)
                    : TextButton(
                        onPressed: () {
                          _page++;
                          _load(reset: false);
                        },
                        child: Text(
                          'Load more',
                          style: TextStyle(color: goldColor, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            );
          }

          final m = _items[i];
          final delta = m['delta'] as num;
          final positive = delta > 0;
          final reason = m['reason'] as String;

          return ListTile(
            key: ValueKey(m['id']),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text(
              _reasons[reason] ?? reason,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                '${m['location_code']}',
                _when(m['created_at'] as String),
                if (m['order_item_id'] != null) 'order line ${m['order_item_id']}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            trailing: Text(
              '${positive ? '+' : ''}${formatQuantity(delta)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: positive ? Colors.green.shade600 : theme.colorScheme.error,
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('History · ${widget.title}'),
        elevation: 0,
      ),
      body: body,
    );
  }
}