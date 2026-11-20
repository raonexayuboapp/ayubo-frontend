import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/product_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'favourite_button.dart';
import 'product_image.dart';

typedef ProductData = Map<String, dynamic>;

class CompactProductCard extends StatefulWidget {
  final ProductData product;
  final Map<String, dynamic>? user;
  final double? width;
  final double imageHeight;
  final ValueChanged<bool>? onFavouriteChanged;

  const CompactProductCard({
    super.key,
    required this.product,
    required this.user,
    this.width,
    this.imageHeight = 148,
    this.onFavouriteChanged,
  });

  @override
  State<CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<CompactProductCard> {
  void _openDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: widget.product['id'] as int,
          title: widget.product['name'] as String? ?? 'Product',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? 'en').startsWith('de');
    final isDark = AppTheme.isDark(context);
    final scheme = Theme.of(context).colorScheme;

    final price = (p['price_cents'] as num?)?.toInt();
    final originalPrice = (p['original_price_cents'] as num?)?.toInt();
    final discountCents = (p['discount_cents'] as num?)?.toInt() ?? 0;

    final hasDiscount =
        price != null &&
        originalPrice != null &&
        originalPrice > price &&
        discountCents > 0;

    final inStock = p['in_stock'] == true;
    final productId = p['id'] as int? ?? 0;
    final name = p['name'] as String? ?? '';

    final discountType = p['discount_type']?.toString();
    final discountValue = p['discount_value'];

    String discountLabel() {
      if (discountType == 'percentage' && discountValue != null) {
        final value = double.tryParse(discountValue.toString());
        if (value != null) {
          final formatted = value == value.roundToDouble()
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(2);
          return '$formatted% OFF';
        }
      }
      if (discountType == 'fixed') {
        return isDe ? 'ANGEBOT' : 'SALE';
      }
      return isDe ? 'REDUZIERT' : 'SPECIAL';
    }

    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = hasDiscount
        ? AppTheme.brandGold.withValues(alpha: isDark ? 0.45 : 0.55)
        : (isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.07));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Card Surface
        Container(
          width: widget.width,
          margin: EdgeInsets.only(top: hasDiscount ? 8 : 0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol, width: hasDiscount ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openDetail,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed-Height Product Image Box
                  SizedBox(
                    height: widget.imageHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: inStock ? 1.0 : 0.55,
                          child: ProductImage(url: p['image_url'] as String?),
                        ),

                        // Subtle bottom gradient vignette
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 28,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.14),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Out of Stock Badge
                        if (!inStock)
                          Positioned(
                            bottom: 8,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF141417,
                                ).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n?.outOfStock ??
                                    (isDe ? 'Ausverkauft' : 'Out of stock'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),

                        // Floating Favourite Button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: FavouriteButton(
                            productId: productId,
                            isFavourite: p['is_favourite'] == true,
                            overlay: true,
                            onChanged: (value) {
                              p['is_favourite'] = value;
                              widget.onFavouriteChanged?.call(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Product Details & Price Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (price != null)
                              Text(
                                formatCents(price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: hasDiscount
                                      ? scheme.error
                                      : (isDark
                                            ? AppTheme.brandGold
                                            : AppTheme.brandGoldDark),
                                ),
                              ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formatCents(originalPrice),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ],
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

        // Floating Metallic Gold Ribbon Badge Overlapping Top Edge
        if (hasDiscount)
          Positioned(
            top: 0,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brandGold, AppTheme.brandGoldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                    size: 11,
                    color: Color(0xFF141417),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    discountLabel(),
                    style: const TextStyle(
                      color: Color(0xFF141417),
                      fontSize: 10,
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
}
