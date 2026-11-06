import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_header.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/favourite_button.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';

typedef ProductData = Map<String, dynamic>;

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final String title; // shown in the app bar while the product loads
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.title,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  /// Largest quantity per order, by product type. The server enforces the same limits: this only keeps the
  /// stepper honest. A type that is missing here (courses) cannot be bought in the app yet.
  static const _maxByType = {
    'physical': 99,
    'gift_voucher': 10,
    'service': 10,
    'membership': 1,
  };

  ProductData? _product;
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

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
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

  Future<void> _addToCart(int variantId) async {
    if (_adding) return; // ignore a second tap while the first is still being sent

    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: l10n?.addToCart ?? 'Add to Cart',
        message: isDe
            ? 'Melden Sie sich an oder erstellen Sie ein Konto, um "${_product?['name'] ?? 'Artikel'}" in Ihren Warenkorb zu legen.'
            : 'Sign in or create an account to add "${_product?['name'] ?? 'items'}" to your cart.',
      );
      if (user == null || !mounted) return;
    }

    setState(() => _adding = true);
    try {
      await ApiService.instance.addToCart(variantId, _quantity);
      if (!mounted) return;
      final count = CartState.instance.count.value;
      _snack(
        isDe
            ? 'In Ihren Warenkorb gelegt. Sie haben $count Artikel in Ihrem Warenkorb.'
            : 'Added to your cart. You have $count item${count == 1 ? '' : 's'} in your cart.',
      );
    } on ApiException catch (e) {
      if (mounted && e.statusCode != 401) _snack(e.message); // for example "Only 5 available."
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// "100 g", or the SKU when the variant has no pack size.
  String _variantLabel(ProductData v) {
    final pack = v['pack_quantity'] as num?;
    if (pack == null) return v['sku'] as String;
    return '${formatQuantity(pack)} ${(v['unit'] as String?) ?? ''}'.trim();
  }

  Widget _section(String title, String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.nature_outlined,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartRow(String type, ProductData? v, bool inStock) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;
    final maxQty = _maxByType[type];

    if (maxQty == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: null,
            child: Text(isDe ? 'Auf Website buchen' : 'Book on our website'),
          ),
          const SizedBox(height: 8),
          Text(
            isDe
                ? 'Dieser Artikel kann noch nicht in der App gekauft werden.'
                : 'This item cannot be bought in the app yet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    final variantId = v?['id'] as int?;
    final canAdd = variantId != null && inStock && !_adding;

    return Row(
      children: [
        if (maxQty > 1) ...[
          QuantityStepper(
            value: _quantity,
            max: maxQty,
            enabled: !_adding,
            onChanged: (q) => setState(() => _quantity = q),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: canAdd ? AppTheme.brandGold : Colors.grey,
                foregroundColor: const Color(0xFF1B4332),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: canAdd ? 2 : 0,
              ),
              onPressed: canAdd ? () => _addToCart(variantId) : null,
              icon: _adding
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B4332)),
                      ),
                    )
                  : const Icon(Icons.add_shopping_cart_rounded),
              label: Text(
                variantId != null && !inStock
                    ? (l10n?.outOfStock ?? 'Out of Stock')
                    : (l10n?.addToCart ?? 'Add to Cart'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

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
              onPressed: _load,
              child: Text(l10n?.retry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    final p = _product!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = p['product_type'] as String;
    final variants = (p['variants'] as List<dynamic>).cast<ProductData>();
    final images = (p['images'] as List<dynamic>).cast<ProductData>();
    final categories = (p['categories'] as List<dynamic>).cast<ProductData>();
    final v = variants.isEmpty ? null : variants[_variant];
    final inStock = v != null && v['in_stock'] == true;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Image Carousel Header
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.brandGold.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGold.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: images.isEmpty
                ? const ProductImage()
                : PageView(
                    children: [
                      for (final i in images)
                        ProductImage(url: i['url'] as String?),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Product Name
        Text(
          p['name'] as String,
          style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
                letterSpacing: -0.5,
              ),
        ),

        const SizedBox(height: 8),

        // Price & VAT
        if (v != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatCents(v['price_cents'] as int),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.brandGoldDark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.taxIncluded ?? 'incl. VAT',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],

        // Stock Status Indicator Badge
        if (type == 'physical') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: inStock
                      ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                      : scheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: inStock
                        ? AppTheme.primaryGreen
                        : scheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inStock
                          ? Icons.check_circle_outline_rounded
                          : Icons.highlight_off_rounded,
                      size: 14,
                      color: inStock ? AppTheme.primaryGreen : scheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      inStock
                          ? (isDe ? 'AUF LAGER' : 'IN STOCK')
                          : (isDe ? 'NICHT AUF LAGER' : 'OUT OF STOCK'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: inStock ? AppTheme.primaryGreen : scheme.error,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        // Variants Chips Selector
        if (variants.length > 1) ...[
          const SizedBox(height: 18),
          Text(
            l10n?.selectPackSize ?? 'Select Pack Size:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < variants.length; i++)
                ChoiceChip(
                  label: Text(_variantLabel(variants[i])),
                  selected: i == _variant,
                  selectedColor: AppTheme.primaryGreen,
                  backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                  labelStyle: TextStyle(
                    color: i == _variant ? Colors.white : AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppTheme.brandGold.withValues(alpha: 0.4),
                    ),
                  ),
                  onSelected: (_) => setState(() {
                    _variant = i;
                    _quantity = 1;
                  }),
                ),
            ],
          ),
        ],

        // Sections
        _section(l10n?.description ?? 'Description', p['description'] as String?),
        _section(l10n?.ingredients ?? 'Ingredients', p['ingredients'] as String?),
        _section(l10n?.allergens ?? 'Allergens', p['allergens'] as String?),

        // Category Tags
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                Chip(
                  label: Text(
                    c['name'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: AppTheme.brandGold.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: AppTheme.brandGold.withValues(alpha: 0.4),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        // Cart Action Row
        _cartRow(type, v, inStock),

        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _favourite);
      },
      child: Scaffold(
        appBar: AppHeader(
          title: widget.title,
          subtitle: _product?['category']?['name'] as String?,
          showBackButton: true,
          onBack: () => Navigator.pop(context, _favourite),
          actions: [
            if (_favourite != null)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: FavouriteButton(
                  productId: widget.productId,
                  isFavourite: _favourite!,
                  onChanged: (v) => _favourite = v,
                ),
              ),
          ],
        ),
        body: _body(),
      ),
    );
  }
}