import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/compact_product_card.dart';

typedef ProductData = Map<String, dynamic>;
typedef CategoryData = Map<String, dynamic>;

class ProductsScreen extends StatefulWidget {
  final dynamic user;
  final String initialSearch;
  final int? initialCategoryId;
  final String initialSort;

  const ProductsScreen({
    super.key,
    this.user,
    this.initialSearch = '',
    this.initialCategoryId,
    this.initialSort = 'newest',
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const List<String> _sortKeys = [
    'newest',
    'name',
    'price_asc',
    'price_desc',
  ];

  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialSearch.trim(),
  );

  final ScrollController _scrollController = ScrollController();

  List<CategoryData> _categories = [];
  List<ProductData> _products = [];

  String _searchQuery = '';
  int? _categoryId;
  String _sort = 'newest';

  int _page = 1;
  int _total = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _loadingCategories = true;

  String? _error;

  int _requestId = 0;
  String? _loadedLanguage;
  int _categoryRequestId = 0;

  @override
  void initState() {
    super.initState();

    _searchQuery = widget.initialSearch.trim();
    _categoryId = widget.initialCategoryId;
    _sort = _sortKeys.contains(widget.initialSort)
        ? widget.initialSort
        : 'newest';

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    _loadCategories();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final language = Localizations.localeOf(context).languageCode;

    if (_loadedLanguage == null) {
      // Initial load is already handled by initState().
      _loadedLanguage = language;
      return;
    }

    if (_loadedLanguage != language) {
      _loadedLanguage = language;

      // Reload database-backed translations in the selected language.
      _loadCategories();
      _load();
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isGerman => Localizations.localeOf(context).languageCode == 'de';

  String _sortLabel(String key) {
    switch (key) {
      case 'name':
        return 'Name (A–Z)';
      case 'price_asc':
        return _isGerman ? 'Preis: aufsteigend' : 'Price: Low to High';
      case 'price_desc':
        return _isGerman ? 'Preis: absteigend' : 'Price: High to Low';
      case 'newest':
      default:
        return _isGerman ? 'Neueste zuerst' : 'Newest First';
    }
  }

  Future<void> _loadCategories() async {
    final requestId = ++_categoryRequestId;

    try {
      final response = await ApiService.instance.listCategories();

      if (!mounted || requestId != _categoryRequestId) return;

      setState(() {
        _categories = response;
        _loadingCategories = false;
      });
    } on ApiException {
      if (!mounted || requestId != _categoryRequestId) return;
      setState(() => _loadingCategories = false);
    } catch (_) {
      if (!mounted || requestId != _categoryRequestId) return;
      setState(() => _loadingCategories = false);
    }
  }

  void _applySearch() {
    FocusScope.of(context).unfocus();
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;

    setState(() {
      _searchQuery = query;
    });
    _load();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _categoryId = null;
      _sort = 'newest';
    });
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _requestId++;

      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _page = 1;
        _products = [];
      });
    } else {
      if (_loading || _loadingMore || _products.length >= _total) {
        return;
      }

      setState(() {
        _loadingMore = true;
        _page++;
      });
    }

    final currentRequestId = _requestId;
    final requestedPage = _page;

    try {
      final response = await ApiService.instance.listProducts(
        search: _searchQuery,
        categoryId: _categoryId,
        sort: _sort,
        page: requestedPage,
      );

      if (!mounted || currentRequestId != _requestId) return;

      final products = (response['products'] as List? ?? [])
          .whereType()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final meta = response['meta'] is Map
          ? Map<String, dynamic>.from(response['meta'] as Map)
          : <String, dynamic>{};

      final total = (meta['total'] as num?)?.toInt() ?? products.length;

      setState(() {
        if (reset) {
          _products = products;
        } else {
          _products = [..._products, ...products];
        }

        _total = total;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || currentRequestId != _requestId) return;

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.message;

        if (!reset) {
          _page = (_page - 1).clamp(1, 999999);
        }
      });

      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted || currentRequestId != _requestId) return;

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Something went wrong. Please try again.';

        if (!reset) {
          _page = (_page - 1).clamp(1, 999999);
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 400) {
      if (!_loading && !_loadingMore && _products.length < _total) {
        _load(reset: false);
      }
    }
  }

  // ===========================================================================
  // 1. SEARCH BAR (Using AppTheme.inputDecoration)
  // ===========================================================================
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _applySearch(),
        style: AppTheme.bodyStyle(context),
        decoration: AppTheme.inputDecoration(
          context,
          hintText: _isGerman
              ? 'Nach Bio-Tee, Gewürzen & mehr suchen...'
              : 'Search organic teas, spices & more...',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: AppTheme.goldAccent(context),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: _isGerman ? 'Suche löschen' : 'Clear search',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textSecondary(context),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _applySearch();
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. CATEGORY FILTER PILLS
  // ===========================================================================
  Widget _buildCategoryFilters() {
    if (_loadingCategories && _categories.isEmpty) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.brandGold,
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _categoryPill(
            label: _isGerman ? 'Alle' : 'All',
            selected: _categoryId == null,
            onTap: () {
              if (_categoryId == null) return;
              setState(() => _categoryId = null);
              _load();
            },
          ),
          ..._categories.map((category) {
            final id = (category['id'] as num?)?.toInt();
            final name = (category['name'] ?? '').toString();

            if (id == null || name.isEmpty) {
              return const SizedBox.shrink();
            }

            return _categoryPill(
              label: name,
              selected: _categoryId == id,
              onTap: () {
                if (_categoryId == id) return;
                setState(() => _categoryId = id);
                _load();
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppTheme.brandGold : AppTheme.primaryGreen)
                : AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (isDark ? AppTheme.brandGold : AppTheme.primaryGreen)
                  : AppTheme.borderColor(context),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          (isDark ? AppTheme.brandGold : AppTheme.primaryGreen)
                              .withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? (isDark ? const Color(0xFF0E1712) : Colors.white)
                    : AppTheme.textPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. RESULTS COUNT & SORT PILL CONTROL
  // ===========================================================================
  Widget _buildSortControl() {
    final countText = _loading && _products.isEmpty
        ? (_isGerman ? 'Produkte laden...' : 'Loading products...')
        : (_isGerman
              ? '$_total ${_total == 1 ? 'Produkt' : 'Produkte'}'
              : '$_total ${_total == 1 ? 'Product' : 'Products'}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countText,
              style: AppTheme.sectionHeadingStyle(
                context,
              ).copyWith(fontSize: 14, color: AppTheme.textSecondary(context)),
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sort,
                isDense: true,
                dropdownColor: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(14),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppTheme.goldAccent(context),
                ),
                items: _sortKeys.map((key) {
                  final isSelected = key == _sort;
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _sortLabel(key),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.goldAccent(context)
                              : AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null || value == _sort) return;
                  setState(() => _sort = value);
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. PRODUCT GRID & STATES
  // ===========================================================================
  Widget _buildContent() {
    if (_loading && _products.isEmpty) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.brandGold,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null && _products.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSubtleColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 32,
                    color: AppTheme.goldAccent(context),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyStyle(context),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => _load(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_isGerman ? 'Erneut versuchen' : 'Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      final hasActiveFilter = _searchQuery.isNotEmpty || _categoryId != null;

      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSubtleColor(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Icon(
                    Icons.spa_outlined,
                    size: 34,
                    color: AppTheme.goldAccent(context),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isGerman ? 'Keine Produkte gefunden' : 'No products found',
                  style: AppTheme.sectionHeadingStyle(context),
                ),
                const SizedBox(height: 6),
                Text(
                  _isGerman
                      ? 'Versuche einen anderen Suchbegriff oder wähle eine andere Kategorie.'
                      : 'Try another search term or explore a different category.',
                  textAlign: TextAlign.center,
                  style: AppTheme.descriptionStyle(context),
                ),
                if (hasActiveFilter) ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary(context),
                      side: BorderSide(color: AppTheme.goldAccent(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                    label: Text(
                      _isGerman ? 'Filter zurücksetzen' : 'Reset Filters',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: () => _load(),
        color: AppTheme.brandGold,
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          itemCount: _products.length + (_loadingMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= _products.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.brandGold,
                  ),
                ),
              );
            }

            final product = _products[index];

            return CompactProductCard(
              product: product,
              user: widget.user,
              onFavouriteChanged: (value) {
                product['is_favourite'] = value;
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        user: widget.user,
        title: _isGerman ? 'Produkte' : 'Products',
        subtitle: _isGerman
            ? 'Ceylon Bio-Kollektion'
            : 'Ceylon Organic Collection',
      ),
      body: Column(
        children: [
          _buildSearchRow(),
          _buildCategoryFilters(),
          _buildSortControl(),
          _buildContent(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(currentIndex: 1, user: widget.user),
    );
  }
}
