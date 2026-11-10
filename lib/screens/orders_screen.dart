
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/product_image.dart';
import 'order_detail_screen.dart';

typedef UserOrderData = Map<String, dynamic>;

class OrdersScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const OrdersScreen({super.key, required this.user});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<UserOrderData> _orders = [];
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
      final list =
      (data['orders'] as List<dynamic>).cast<UserOrderData>();

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
          _page--;
        }
      });

      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _open(UserOrderData o) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: o['id'] as int,
          number: o['number'] as String,
          user: widget.user,
        ),
      ),
    );

    if (mounted) _load(reset: true);
  }

  Widget _card(UserOrderData o) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final isDe =
    (l10n?.localeName ?? currentAppLocale).startsWith('de');

    final preview = (o['preview'] as List<dynamic>).cast<String>();
    final count = o['item_count'] as int;
    final orderNumber = o['number'] as String;

    // First product name is displayed as the highlighted title.
    final productName = preview.isNotEmpty
        ? preview.first
        : (isDe ? 'Bestellung' : 'Order');

    return Container(
      key: ValueKey(o['id']),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(o),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ProductImage(
                      url: o['image_url'] as String?,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Order information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Highlighted product name at the top
                      Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // Order number underneath product name
                      Text(
                        orderNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Order date
                      Text(
                        formatDate(o['created_at'] as String?),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),

                      // Additional product names
                      if (preview.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview.skip(1).join(', ') +
                              (count > preview.length ? ' …' : ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Order and payment status
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          OrderStatusChip(
                            status: o['status'] as String,
                          ),
                          OrderStatusChip(
                            status: o['payment_status'] as String,
                            payment: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Total price and item count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCents(o['total_cents'] as int),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: goldColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDe
                          ? '$count Artikel'
                          : '$count item${count == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    Widget body;

    if (_loading && _orders.isEmpty) {
      body = Center(
        child: CircularProgressIndicator(
          color: goldColor,
          strokeWidth: 2,
        ),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n?.retry ?? 'Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: goldColor,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_orders.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: goldColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: goldColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.noOrdersYet ??
                        'You have not placed an order yet.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        AppBottomBar.open(context, 1, widget.user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: goldColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n?.exploreCollection ?? 'Browse products',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final hasMore = _orders.length < _total;

      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: goldColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _orders.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _loading
                      ? CircularProgressIndicator(
                    color: goldColor,
                    strokeWidth: 2,
                  )
                      : TextButton(
                    onPressed: () {
                      _page++;
                      _load(reset: false);
                    },
                    child: Text(
                      l10n?.loadMore ?? 'Load more',
                      style: TextStyle(
                        color: goldColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }

            return _card(_orders[i]);
          },
        ),
      );
    }

    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.myOrders ?? 'My Orders',
        subtitle:
        '$_total ${isDe ? (_total == 1 ? 'Bestellung' : 'Bestellungen') : (_total == 1 ? 'order' : 'orders')}',
        user: widget.user,
        showBackButton: true,
      ),
      body: body,
    );
  }
}
