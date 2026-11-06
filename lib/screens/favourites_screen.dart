import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_header.dart';
import '../widgets/favourite_button.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

typedef ProductData = Map<String, dynamic>;

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<ProductData> _items = [];
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
      final data = await ApiService.instance.listFavourites(page: _page);
      final list = (data['products'] as List<dynamic>).cast<ProductData>();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    }
  }

  Future<void> _openDetail(ProductData p) async {
    final favourite = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: p['id'] as int,
          title: p['name'] as String,
        ),
      ),
    );
    if (favourite != null && mounted) {
      setState(() => p['is_favourite'] = favourite);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGold),
        ),
      );
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: scheme.onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _load(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: AppTheme.brandGold,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.brandGold.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.favorite_outline_rounded,
                  size: 64,
                  color: AppTheme.brandGoldDark,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Favourites Saved',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on any product to save it here for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else {
      final hasMore = _items.length < _total;
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: AppTheme.brandGold,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _items.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            _page++;
                            _load(reset: false);
                          },
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: const Text(
                      'Load More',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }

            final p = _items[i];
            final price = p['price_cents'] as int?;
            final inStock = p['in_stock'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandGold.withValues(alpha: 0.04),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ListTile(
                key: ValueKey(p['id']),
                contentPadding: const EdgeInsets.all(12),
                onTap: () => _openDetail(p),
                leading: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.brandGold.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: ProductImage(url: p['image_url'] as String?),
                  ),
                ),
                title: Text(
                  p['name'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      if (price != null)
                        Text(
                          formatCents(price),
                          style: const TextStyle(
                            color: AppTheme.brandGoldDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      if (!inStock) ...[
                        if (price != null) const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: scheme.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: FavouriteButton(
                  productId: p['id'] as int,
                  isFavourite: p['is_favourite'] == true,
                  onChanged: (v) => p['is_favourite'] = v,
                ),
              ),
            );
          },
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: isDe ? 'Meine Favoriten' : 'My Favourites',
        subtitle: '$_total ${isDe ? (_total == 1 ? 'Artikel' : 'Artikel') : (_total == 1 ? 'item' : 'items')}',
        showBackButton: true,
      ),
      body: body,
    );
  }
}