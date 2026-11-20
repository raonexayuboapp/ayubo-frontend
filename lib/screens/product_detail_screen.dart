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
<<<<<<< Updated upstream
  /// Largest quantity per order, by product type. The server enforces the same limits: this only keeps the
  /// stepper honest. A type that is missing here (courses) cannot be bought in the app yet.
=======
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
  bool? _favourite; // null until the product has loaded
=======
  int _imagePage = 0;
  bool? _favourite;
>>>>>>> Stashed changes
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) {
<<<<<<< Updated upstream
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
=======
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
=======
        _variant = 0;
        _quantity = 1;
        _imagePage = 0;
>>>>>>> Stashed changes
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

  String _variantLabel(ProductData v) {
    final pack = v['pack_quantity'] as num?;
    if (pack == null) return v['sku'] as String;
    return '${formatQuantity(pack)} ${(v['unit'] as String?) ?? ''}'.trim();
  }

<<<<<<< Updated upstream
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
=======
  int _cents(ProductData? variant, String key) {
    final value = variant?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _hasVisibleDiscount(ProductData? variant) {
    if (variant == null) return false;
    final original = _cents(variant, 'original_price_cents');
    final current = _cents(variant, 'price_cents');
    return original > current && current >= 0;
  }

  String _discountLabel(ProductData variant, bool isDe) {
    final type = variant['discount_type'] as String?;
    if (type == 'percentage') {
      final value = variant['discount_value'];
      if (value is num) {
        final percentage = value % 1 == 0
            ? value.toInt().toString()
            : value.toString();
        return '$percentage% OFF';
      }
    }
    return isDe ? 'ANGEBOT' : 'SALE';
  }

  // ===========================================================================
  // 1. IMAGE GALLERY WITH INDICATORS & FLOATING DISCOUNT BADGE
  // ===========================================================================
  Widget _buildImageGallery(
    List<ProductData> images,
    ProductData? variant,
    bool isDe,
  ) {
    final hasDiscount = _hasVisibleDiscount(variant);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 300,
          margin: EdgeInsets.only(top: hasDiscount ? 8 : 0),
          decoration: AppTheme.cardDecoration(
            context,
            radius: 24,
            hasBorder: true,
            hasShadow: true,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              images.isEmpty
                  ? const ProductImage()
                  : PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (idx) => setState(() => _imagePage = idx),
                      itemBuilder: (_, idx) =>
                          ProductImage(url: images[idx]['url'] as String?),
                    ),

              // Subtle bottom gradient for page dots
              if (images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                ),

              // Page Indicator Dots
              if (images.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (i) {
                      final active = i == _imagePage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: active ? 18 : 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.brandGold
                              : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
>>>>>>> Stashed changes
        ),

        // Floating Metallic Gold Discount Ribbon
        if (hasDiscount && variant != null)
          Positioned(
            top: 0,
            left: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brandGold, AppTheme.brandGoldDark],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandGold.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    size: 12,
                    color: Color(0xFF1B2E24),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _discountLabel(variant, isDe),
                    style: const TextStyle(
                      color: Color(0xFF1B2E24),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

<<<<<<< Updated upstream
=======
  // ===========================================================================
  // 2. ORGANIC QUALITY HIGHLIGHT PILLS (Inspired by reference)
  // ===========================================================================
  Widget _buildHighlightPills(bool isDe) {
    final items = [
      (
        Icons.eco_outlined,
        isDe ? 'Streng biologisch geerntet' : 'Strictly organically harvested',
      ),
      (
        Icons.workspace_premium_outlined,
        isDe
            ? 'Premium-Qualität aus Sri Lanka'
            : 'Premium quality from Sri Lanka',
      ),
      (
        Icons.public_rounded,
        isDe
            ? '100 % rein & nachhaltig angebaut'
            : '100% pure & sustainably grown',
      ),
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardSubtleColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.borderColor(context),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(item.$1, size: 17, color: AppTheme.primaryAction(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // 3. PRICE & STOCK BANNER
  // ===========================================================================
  Widget _priceAndStockSection(
    ProductData variant,
    String type,
    bool inStock,
    bool isDe,
    ColorScheme scheme,
  ) {
    final currentPrice = _cents(variant, 'price_cents');
    final originalPrice = _cents(variant, 'original_price_cents');
    final hasDiscount = _hasVisibleDiscount(variant);
    final savings = hasDiscount ? originalPrice - currentPrice : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatCents(currentPrice),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: hasDiscount
                    ? scheme.error
                    : AppTheme.goldAccent(context),
              ),
            ),
            if (hasDiscount) ...[
              const SizedBox(width: 10),
              Text(
                formatCents(originalPrice),
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.lineThrough,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.taxIncluded ?? 'incl. VAT',
              style: AppTheme.captionStyle(context),
            ),
          ],
        ),

        if (hasDiscount) ...[
          const SizedBox(height: 6),
          Text(
            isDe
                ? 'Sie sparen ${formatCents(savings)} bei dieser Auswahl'
                : 'You save ${formatCents(savings)} on this selection',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryAction(context),
            ),
          ),
        ],

        // Clean Stock Status Banner (Inspired by reference)
        if (type == 'physical') ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: inStock
                  ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                  : scheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: inStock
                    ? AppTheme.primaryAction(context).withValues(alpha: 0.3)
                    : scheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  inStock
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 17,
                  color: inStock
                      ? AppTheme.primaryAction(context)
                      : scheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    inStock
                        ? (isDe
                              ? 'Auf Lager – Versandfertig in 24 Stunden'
                              : 'In Stock – Ready to ship within 24 hours')
                        : (isDe
                              ? 'Derzeit ausverkauft'
                              : 'Currently out of stock'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: inStock
                          ? AppTheme.primaryAction(context)
                          : scheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 4. VARIANT / PACK SIZE SELECTOR CARDS
  // ===========================================================================
  Widget _buildVariantSelector(List<ProductData> variants) {
    if (variants.length <= 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          l10n?.selectPackSize ?? 'Select Pack Size',
          style: AppTheme.sectionHeadingStyle(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < variants.length; i++)
              InkWell(
                onTap: () {
                  setState(() {
                    _variant = i;
                    _quantity = 1;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: i == _variant
                        ? (isDark
                              ? AppTheme.surfaceSubtleDark
                              : AppTheme.brandGoldLight.withValues(alpha: 0.35))
                        : AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: i == _variant
                          ? AppTheme.brandGold
                          : AppTheme.borderColor(context),
                      width: i == _variant ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _variantLabel(variants[i]),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatCents(_cents(variants[i], 'price_cents')),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: i == _variant
                              ? AppTheme.goldAccent(context)
                              : AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. 2x2 SERVICE & TRUST GRID (Inspired by reference)
  // ===========================================================================
  Widget _buildTrustGrid(bool isDe) {
    final cards = [
      (
        Icons.local_shipping_outlined,
        isDe ? 'Kostenloser Versand' : 'Free Shipping',
        isDe ? 'Ab €50 Bestellwert' : 'Orders over €50',
      ),
      (
        Icons.verified_outlined,
        isDe ? 'Deutsches Start-up' : 'German Start-up',
        isDe ? 'Sri Lanka & Deutschland' : 'Sri Lanka & Germany',
      ),
      (
        Icons.support_agent_rounded,
        isDe ? '24/7 Kundenservice' : '24/7 Support',
        isDe ? 'Immer für Sie da' : 'Always here for you',
      ),
      (
        Icons.autorenew_rounded,
        isDe ? '14 Tage Rückgabe' : '14-Day Returns',
        isDe ? 'Kein Risiko' : 'Hassle-free policy',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.75,
          ),
          itemBuilder: (context, index) {
            final item = cards[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$1, size: 20, color: AppTheme.goldAccent(context)),
                  const SizedBox(height: 5),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionStyle(
                      context,
                    ).copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. COLLAPSIBLE DETAILS ACCORDION
  // ===========================================================================
  Widget _buildAccordionSection(
    String title,
    String? text,
    IconData icon, {
    bool initiallyExpanded = false,
  }) {
    if (text == null || text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: AppTheme.cardDecoration(
        context,
        radius: 16,
        hasBorder: true,
        hasShadow: false,
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, size: 19, color: AppTheme.primaryAction(context)),
          title: Text(
            title,
            style: AppTheme.cardTitleStyle(
              context,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          iconColor: AppTheme.goldAccent(context),
          collapsedIconColor: AppTheme.textSecondary(context),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 7. STICKY BOTTOM PURCHASE BAR
  // ===========================================================================
  Widget? _buildStickyBottomBar() {
    if (_loading || _error != null || _product == null) return null;

    final p = _product!;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;
    final type = p['product_type'] as String;
    final variants = (p['variants'] as List<dynamic>).cast<ProductData>();
    final v = variants.isEmpty
        ? null
        : variants[_variant.clamp(0, variants.length - 1)];
    final inStock = v != null && v['in_stock'] == true;
    final maxQty = _maxByType[type];

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: maxQty == null
          ? SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: null,
                child: Text(
                  isDe ? 'Auf Website buchen' : 'Book on our website',
                ),
              ),
            )
          : Builder(
              builder: (_) {
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
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAdd
                                ? AppTheme.brandGold
                                : AppTheme.cardSubtleColor(context),
                            foregroundColor: canAdd
                                ? const Color(0xFF1B2E24)
                                : AppTheme.textSecondary(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: canAdd
                              ? () => _addToCart(variantId)
                              : null,
                          icon: _adding
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1B2E24),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20,
                                ),
                          label: Text(
                            variantId != null && !inStock
                                ? (l10n?.outOfStock ?? 'Out of Stock')
                                : (l10n?.addToCart ?? 'Add to Cart'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ===========================================================================
  // MAIN BODY
  // ===========================================================================
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
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
=======
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(context),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: Text(l10n?.retry ?? 'Retry'),
              ),
            ],
          ),
>>>>>>> Stashed changes
        ),
      );
    }

    final p = _product!;
    final type = p['product_type'] as String;
    final variants = (p['variants'] as List<dynamic>).cast<ProductData>();
    final images = (p['images'] as List<dynamic>).cast<ProductData>();
    final categories = (p['categories'] as List<dynamic>).cast<ProductData>();
<<<<<<< Updated upstream
    final v = variants.isEmpty ? null : variants[_variant];
=======

    final v = variants.isEmpty
        ? null
        : variants[_variant.clamp(0, variants.length - 1)];
>>>>>>> Stashed changes
    final inStock = v != null && v['in_stock'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
<<<<<<< Updated upstream
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
=======
        // 1. Image Gallery
        _buildImageGallery(images, v, isDe),

        const SizedBox(height: 20),

        // 2. Category Pill + Product Title
>>>>>>> Stashed changes
        if (categories.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in categories)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (c['name'] as String).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppTheme.goldAccent(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        Text(
          p['name'] as String,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.4,
            color: AppTheme.textPrimary(context),
          ),
        ),

        const SizedBox(height: 14),

        // 3. Organic Highlight Pills
        _buildHighlightPills(isDe),

        const SizedBox(height: 12),

        // 4. Price & Stock Availability
        if (v != null) _priceAndStockSection(v, type, inStock, isDe, scheme),

        // 5. Pack Size Selector
        _buildVariantSelector(variants),

        // 6. Trust & Delivery 2x2 Grid
        _buildTrustGrid(isDe),

        const SizedBox(height: 10),

        // 7. Collapsible Product Information
        _buildAccordionSection(
          l10n?.description ?? 'Description',
          p['description'] as String?,
          Icons.spa_outlined,
          initiallyExpanded: true,
        ),
        _buildAccordionSection(
          l10n?.ingredients ?? 'Ingredients',
          p['ingredients'] as String?,
          Icons.grass_outlined,
        ),
        _buildAccordionSection(
          l10n?.allergens ?? 'Allergens',
          p['allergens'] as String?,
          Icons.info_outline_rounded,
        ),
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
        bottomNavigationBar: _buildStickyBottomBar(),
      ),
    );
  }
}