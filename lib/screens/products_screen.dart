import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';
import '../widgets/favourite_button.dart';

class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool focusSearch; // opened from the search pill in the top bar
  const ProductsScreen({super.key, required this.user, this.focusSearch = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const _sorts = {
    'newest': 'Newest',
    'name': 'Name A to Z',
    'price_asc': 'Price: low to high',
    'price_desc': 'Price: high to low',
  };

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  int? _categoryId;
  String _sort = 'newest';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _requestId = 0; // an answer that belongs to an older request is ignored

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadCategories();
    _load();
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final tree = await ApiService.instance.listCategories();
      if (mounted) setState(() => _categories = tree);
    } on ApiException {
      // The chips are optional: the catalogue works without them.
    }
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
        search: _search.text.trim(),
        categoryId: _categoryId,
        sort: _sort,
        page: _page,
      );
      if (!mounted || request != _requestId) return;

      final list = (data['products'] as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() {
        _products = reset ? list : [..._products, ...list];
        _total = (data['meta'] as Map<String, dynamic>)['total'] as int;
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
          _page--; // let the next scroll try this page again
        }
      });
      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _onScroll() {
    final nearEnd = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300;
    if (nearEnd && !_loading && !_loadingMore && _products.length < _total) {
      _page++;
      _load(reset: false);
    }
  }

  void _onSearchChanged(String _) {
    setState(() {}); // shows or hides the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openDetail(Map<String, dynamic> p) async {
    final favourite = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: p['id'] as int, title: p['name'] as String),
      ),
    );
    // The detail page hands back the heart state, so the card shows it without a reload.
    if (favourite != null && mounted) setState(() => p['is_favourite'] = favourite);
  }

  Widget _card(Map<String, dynamic> p) {
    final theme = Theme.of(context);
    final price = p['price_cents'] as int?;
    final inStock = p['in_stock'] == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: p['image_url'] as String?),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: FavouriteButton(
                      productId: p['id'] as int,
                      isFavourite: p['is_favourite'] == true,
                      overlay: true,
                      onChanged: (v) => p['is_favourite'] = v,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] as String,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  if (price != null)
                    Text(formatCents(price), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (!inStock)
                    Text('Out of stock', style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    if (_products.isEmpty) {
      return const Center(child: Text('No products found.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _products.length,
        itemBuilder: (_, i) => _card(_products[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(user: widget.user, onSearchTap: () => _searchFocus.requestFocus()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                initialValue: _sort,
                onSelected: (v) {
                  setState(() => _sort = v);
                  _load();
                },
                itemBuilder: (_) => [
                  for (final e in _sorts.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                ],
              ),
            ]),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _categoryId == null,
                      onSelected: (_) {
                        setState(() => _categoryId = null);
                        _load();
                      },
                    ),
                  ),
                  for (final c in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c['name'] as String),
                        selected: _categoryId == c['id'],
                        onSelected: (_) {
                          setState(() => _categoryId = c['id'] as int);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _content()),
          if (_loadingMore) const LinearProgressIndicator(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(currentIndex: 1, user: widget.user),
    );
  }
}