import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/favourite_button.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

typedef ProductData = Map<String, dynamic>;
typedef CategoryData = Map<String, dynamic>;

class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String initialSearch;
  final int? initialCategoryId;

  const ProductsScreen({
    super.key,
    required this.user,
    this.initialSearch = '',
    this.initialCategoryId,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const _sortKeys = ['newest', 'name', 'price_asc', 'price_desc'];

  String _sortLabel(String key, [BuildContext? ctx]) {
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    if (isDe) {
      return switch (key) {
        'newest' => 'Neuheiten',
        'name' => 'Name A bis Z',
        'price_asc' => 'Preis: Aufsteigend',
        'price_desc' => 'Preis: Absteigend',
        _ => key,
      };
    }
    return switch (key) {
      'newest' => 'Newest',
      'name' => 'Name A to Z',
      'price_asc' => 'Price: Low to High',
      'price_desc' => 'Price: High to Low',
      _ => key,
    };
  }

  final _scroll = ScrollController();
  late final TextEditingController _searchController =
      TextEditingController(text: widget.initialSearch.trim());

  List<CategoryData> _categories = [];
  List<ProductData> _products = [];

  late String _searchQuery;

  int? _categoryId;
  String _sort = 'newest';
  int _page = 1;
  int _total = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    _searchQuery = widget.initialSearch.trim();
    _categoryId = widget.initialCategoryId;

    _scroll.addListener(_onScroll);
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final tree = await ApiService.instance.listCategories();

      if (mounted) {
        setState(() => _categories = tree.cast<CategoryData>());
      }
    } on ApiException {
      // Categories are optional.
    }
  }

  Future<void> _applySearch(String query) async {
    if (!mounted) return;

    setState(() {
      _searchQuery = query.trim();
    });

    await _load();
  }

  Future<void> _load({bool reset = true}) async {
    final request = ++_requestId;

    setState(() {
      if (reset) {
        _page = 1;
        _loading = true;
        _loadingMore = false;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final data = await ApiService.instance.listProducts(
        search: _searchQuery,
        categoryId: _categoryId,
        sort: _sort,
        page: _page,
      );

      if (!mounted || request != _requestId) return;

      final products = (data['products'] as List<dynamic>).cast<ProductData>();
      final meta = data['meta'] as Map<String, dynamic>;

      setState(() {
        _products = reset ? products : [..._products, ...products];
        _total = (meta['total'] as num).toInt();
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _requestId) return;

      setState(() {
        _loading = false;
        _loadingMore = false;

        if (reset) {
          _error = e.message;
        } else {
          _page--;
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
    } catch (_) {
      if (!mounted || request != _requestId) return;

      setState(() {
        _loading = false;
        _loadingMore = false;

        if (reset) {
          _error = 'Unable to load products. Please try again.';
        } else {
          _page--;
        }
      });
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;

    final nearEnd = _scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300;

    if (nearEnd && !_loading && !_loadingMore && _products.length < _total) {
      _page++;
      _load(reset: false);
    }
  }

  Future<void> _openDetail(ProductData product) async {
    final favourite = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product['id'] as int,
          title: product['name'] as String,
        ),
      ),
    );

    if (favourite != null && mounted) {
      setState(() {
        product['is_favourite'] = favourite;
      });
    }
  }

  Widget _card(ProductData product) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = product['price_cents'] as int?;
    final inStock = product['in_stock'] == true;

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openDetail(product),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(
                        url: product['image_url'] as String?,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: FavouriteButton(
                          productId: product['id'] as int,
                          isFavourite: product['is_favourite'] == true,
                          overlay: true,
                          onChanged: (value) {
                            if (!mounted) return;
                            setState(() {
                              product['is_favourite'] = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (price != null)
                            Text(
                              formatCents(price),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.brandGoldDark,
                              ),
                            ),
                          if (!inStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.outOfStock ?? 'Out of stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGold),
        ),
      );
    }

    if (_error != null) {
      return Center(
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
              onPressed: () => _load(),
              child: Text(l10n?.retry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        color: AppTheme.brandGold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  Icons.search_off_rounded,
                  size: 64,
                  color: AppTheme.brandGoldDark,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.noProductsFound ?? 'No Products Found',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.noProductsFoundMessage ??
                  'Try clearing your search query or choosing another category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      color: AppTheme.brandGold,
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _products.length,
        itemBuilder: (_, index) => _card(_products[index]),
      ),
    );
  }

  Widget _buildSortControl() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                '${l10n?.catalogue ?? 'Catalogue'} ($_total)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            initialValue: _sort,
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              setState(() => _sort = value);
              _load();
            },
            itemBuilder: (_) => _sortKeys
                .map(
                  (key) => PopupMenuItem<String>(
                    value: key,
                    child: Text(
                      _sortLabel(key, context),
                      style: TextStyle(
                        fontWeight: _sort == key
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _sort == key
                            ? AppTheme.brandGoldDark
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.brandGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandGold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: AppTheme.brandGoldDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sortLabel(_sort, context),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandGoldDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l10n?.allProducts ?? 'All Products'),
              selected: _categoryId == null,
              selectedColor: AppTheme.primaryGreen,
              backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
              labelStyle: TextStyle(
                color: _categoryId == null ? Colors.white : AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppTheme.brandGold.withValues(alpha: 0.4),
                ),
              ),
              onSelected: (_) {
                setState(() => _categoryId = null);
                _load();
              },
            ),
          ),
          for (final category in _categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category['name'] as String),
                selected: _categoryId == category['id'],
                selectedColor: AppTheme.primaryGreen,
                backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                labelStyle: TextStyle(
                  color: _categoryId == category['id']
                      ? Colors.white
                      : AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppTheme.brandGold.withValues(alpha: 0.4),
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _categoryId = category['id'] as int;
                  });
                  _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    final l10n = AppLocalizations.of(context);
    final hint = l10n?.searchWellness ?? 'Search products, wellness...';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _applySearch,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary(context).withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _searchController.clear();
                  _applySearch('');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.navProducts ?? 'Shop',
        subtitle: isDe ? 'Reine Bio-Ceylon-Kräuter & Tees' : 'Pure Organic Ceylon Botanicals',
        user: widget.user,
        showBackButton: Navigator.canPop(context),
      ),
      body: Column(
        children: [
          _buildSearchRow(),
          _buildSortControl(),
          _buildCategoryFilters(),
          Expanded(child: _content()),
          if (_loadingMore)
            const LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGold),
              backgroundColor: AppTheme.primaryGreen,
            ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: 1,
        user: widget.user,
      ),
    );
  }
}