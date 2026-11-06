import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/product_detail_screen.dart';
import '../../services/api_service.dart';
import '../../services/cart_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../widgets/favourite_button.dart';
import '../../widgets/product_image.dart';

typedef ProductData = Map<String, dynamic>;

class CompactProductCard extends StatefulWidget {
  final ProductData product;
  final Map<String, dynamic>? user;
  final double? width;
  final VoidCallback? onAddedToCart;

  const CompactProductCard({
    super.key,
    required this.product,
    required this.user,
    this.width,
    this.onAddedToCart,
  });

  @override
  State<CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<CompactProductCard> {
  bool _adding = false;

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

  Future<void> _addToCart() async {
    if (_adding) return;

    final product = widget.product;
    final variantId = (product['variants'] as List<dynamic>?)?.firstOrNull?['id'] as int? ??
        (product['id'] as int);
    final name = product['name'] as String? ?? 'Product';
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final loggedUser = await showAuthPrompt(
        context,
        title: l10n?.addToCart ?? 'Add to Cart',
        message: isDe
            ? 'Melden Sie sich an oder erstellen Sie ein Konto, um "$name" in Ihren Warenkorb zu legen.'
            : 'Sign in or create an account to add "$name" to your cart.',
      );
      if (loggedUser == null || !mounted) return;
    }

    setState(() => _adding = true);

    try {
      await ApiService.instance.addToCart(variantId, 1);
      if (!mounted) return;
      final count = CartState.instance.count.value;
      widget.onAddedToCart?.call();

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isDe
                  ? '"$name" wurde dem Warenkorb hinzugefügt ($count Artikel).'
                  : '"$name" added to your cart ($count items).',
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: isDe ? 'Warenkorb' : 'View Cart',
              textColor: AppTheme.brandGold,
              onPressed: () => AppBottomBar.open(context, 3, widget.user ?? const {}),
            ),
          ),
        );
    } on ApiException catch (e) {
      if (mounted && e.statusCode != 401) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;
    final isDark = AppTheme.isDark(context);

    final priceCents = (p['price_cents'] as num?)?.toInt() ?? 0;
    final inStock = p['in_stock'] == true;
    final name = p['name'] as String? ?? '';
    final imageUrl = p['image_url'] as String?;
    final productId = p['id'] as int? ?? 0;

    return Container(
      width: widget.width,
      decoration: AppTheme.cardDecoration(
        context,
        radius: 16,
        hasBorder: true,
        hasShadow: true,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openDetail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product Image with 1:1 Aspect Ratio + Badges Overlay
              AspectRatio(
                aspectRatio: 1.05,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(url: imageUrl),

                    // Top-Right Favourite Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: FavouriteButton(
                        productId: productId,
                        isFavourite: p['is_favourite'] == true,
                        overlay: true,
                        onChanged: (val) {
                          p['is_favourite'] = val;
                        },
                      ),
                    ),

                    // Stock Status Badge
                    if (!inStock)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDe ? 'Ausverkauft' : 'Sold out',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Info & Price
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Name (2 lines max)
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Price & Quick Add Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            formatCents(priceCents),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.brandGoldLight : AppTheme.brandGoldDark,
                            ),
                          ),
                        ),

                        // Add to Cart Button
                        if (inStock)
                          InkWell(
                            onTap: _adding ? null : _addToCart,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppTheme.brandGold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _adding
                                  ? const Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF1B4332),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: Color(0xFF1B4332),
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
    );
  }
}

