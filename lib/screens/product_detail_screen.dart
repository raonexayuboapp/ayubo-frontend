import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../utils/money.dart';
import '../widgets/favourite_button.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final String title; // shown in the app bar while the product loads
  const ProductDetailScreen({super.key, required this.productId, required this.title});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  /// Largest quantity per order, by product type. The server enforces the same limits: this only keeps the
  /// stepper honest. A type that is missing here (courses) cannot be bought in the app yet.
  static const _maxByType = {'physical': 99, 'gift_voucher': 10, 'service': 10, 'membership': 1};

  Map<String, dynamic>? _product;
  bool _loading = true;
  String? _error;
  int _variant = 0;
  int _quantity = 1;
  bool? _favourite; // null until the product has loaded
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ApiService.instance.getProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = p;
        _favourite = p['is_favourite'] == true;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _addToCart(int variantId) async {
    if (_adding) return; // ignore a second tap while the first is still being sent

    setState(() => _adding = true);
    try {
      await ApiService.instance.addToCart(variantId, _quantity);
      if (!mounted) return;
      final count = CartState.instance.count.value;
      _snack('Added to your cart. You have $count item${count == 1 ? '' : 's'} in your cart.');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message); // for example "Only 5 available."
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// "100 g", or the SKU when the variant has no pack size.
  String _variantLabel(Map<String, dynamic> v) {
    final pack = v['pack_quantity'] as num?;
    if (pack == null) return v['sku'] as String;
    return '${formatQuantity(pack)} ${(v['unit'] as String?) ?? ''}'.trim();
  }

  Widget _section(String title, String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(text),
      ]),
    );
  }

  Widget _cartRow(String type, Map<String, dynamic>? v, bool inStock) {
    final maxQty = _maxByType[type];

    if (maxQty == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FilledButton(onPressed: null, child: Text('Book on our website')),
        const SizedBox(height: 8),
        Text('This item cannot be bought in the app yet.', style: Theme.of(context).textTheme.bodySmall),
      ]);
    }

    final variantId = v?['id'] as int?;
    final canAdd = variantId != null && inStock && !_adding;

    return Row(children: [
      if (maxQty > 1) ...[
        QuantityStepper(
          value: _quantity,
          max: maxQty,
          enabled: !_adding,
          onChanged: (q) => setState(() => _quantity = q),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: FilledButton.icon(
          onPressed: canAdd ? () => _addToCart(variantId) : null,
          icon: _adding
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_shopping_cart),
          label: Text(variantId != null && !inStock ? 'Out of stock' : 'Add to cart'),
        ),
      ),
    ]);
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final p = _product!;
    final theme = Theme.of(context);
    final type = p['product_type'] as String;
    final variants = (p['variants'] as List<dynamic>).cast<Map<String, dynamic>>();
    final images = (p['images'] as List<dynamic>).cast<Map<String, dynamic>>();
    final categories = (p['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
    final v = variants.isEmpty ? null : variants[_variant];
    final inStock = v != null && v['in_stock'] == true;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: images.isEmpty
                ? const ProductImage()
                : PageView(children: [for (final i in images) ProductImage(url: i['url'] as String?)]),
          ),
        ),
        const SizedBox(height: 16),
        Text(p['name'] as String, style: theme.textTheme.headlineSmall),
        if (v != null) ...[
          const SizedBox(height: 4),
          Text(formatCents(v['price_cents'] as int),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text('incl. VAT', style: theme.textTheme.bodySmall),
        ],
        if (variants.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < variants.length; i++)
              ChoiceChip(
                label: Text(_variantLabel(variants[i])),
                selected: i == _variant,
                onSelected: (_) => setState(() {
                  _variant = i;
                  _quantity = 1;
                }),
              ),
          ]),
        ],
        if (type == 'physical') ...[
          const SizedBox(height: 8),
          Text(
            inStock ? 'In stock' : 'Out of stock',
            style: TextStyle(color: inStock ? Colors.green.shade700 : theme.colorScheme.error),
          ),
        ],
        _section('Description', p['description'] as String?),
        _section('Ingredients', p['ingredients'] as String?),
        _section('Allergens', p['allergens'] as String?),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(spacing: 8, children: [
            for (final c in categories)
              Chip(label: Text(c['name'] as String), visualDensity: VisualDensity.compact),
          ]),
        ],
        const SizedBox(height: 24),
        _cartRow(type, v, inStock),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Going back hands the heart state to the screen that opened this one.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _favourite);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (_favourite != null)
              FavouriteButton(
                productId: widget.productId,
                isFavourite: _favourite!,
                onChanged: (v) => _favourite = v,
              ),
          ],
        ),
        body: _body(),
      ),
    );
  }
}