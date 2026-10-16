import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/product_image.dart';
import '../widgets/favourite_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final String title; // shown in the app bar while the product loads
  const ProductDetailScreen({super.key, required this.productId, required this.title});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  bool _loading = true;
  String? _error;
  int _variant = 0;
  bool? _favourite;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  String _num(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  /// "100 g", or the SKU when the variant has no pack size.
  String _variantLabel(Map<String, dynamic> v) {
    final pack = v['pack_quantity'] as num?;
    if (pack == null) return v['sku'] as String;
    return '${_num(pack)} ${(v['unit'] as String?) ?? ''}'.trim();
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
                onSelected: (_) => setState(() => _variant = i),
              ),
          ]),
        ],
        const SizedBox(height: 8),
        Text(
          inStock ? 'In stock' : 'Out of stock',
          style: TextStyle(color: inStock ? Colors.green.shade700 : theme.colorScheme.error),
        ),
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
        // Stays disabled until the cart is rewritten for product variants.
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Add to cart'),
        ),
        const SizedBox(height: 8),
        Text('Cart for products arrives with the next update.', style: theme.textTheme.bodySmall),
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