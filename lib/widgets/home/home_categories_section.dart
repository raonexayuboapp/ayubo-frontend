import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/products_screen.dart';
import '../../theme/app_theme.dart';

typedef CategoryData = Map<String, dynamic>;

class HomeCategoriesSection extends StatelessWidget {
  final Map<String, dynamic>? user;
  final List<CategoryData> categories;

  const HomeCategoriesSection({
    super.key,
    required this.user,
    required this.categories,
  });

  String _categoryImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('spice') || lower.contains('gewürz') || lower.contains('curry')) {
      return 'assets/images/spices 1.jpg';
    }
    if (lower.contains('tea') || lower.contains('tee') || lower.contains('herbal')) {
      return 'assets/images/tea plantation.jpg';
    }
    if (lower.contains('coconut') || lower.contains('kokos') || lower.contains('water')) {
      return 'assets/images/coconut water.jpg';
    }
    if (lower.contains('cinnamon') || lower.contains('zimt')) {
      return 'assets/images/cinnamon plantation.jpg';
    }
    if (lower.contains('pepper') || lower.contains('pfeffer')) {
      return 'assets/images/pepper plantation.jpg';
    }
    if (lower.contains('voucher') || lower.contains('gutschein') || lower.contains('gift')) {
      return 'assets/images/harmonie_set_for_her.webp';
    }
    if (lower.contains('sandal') || lower.contains('wood') || lower.contains('oil')) {
      return 'assets/images/sandal wood.jpg';
    }
    return 'assets/images/shop.webp';
  }

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('spice') || lower.contains('gewürz')) return Icons.eco_rounded;
    if (lower.contains('tea') || lower.contains('tee')) return Icons.local_cafe_rounded;
    if (lower.contains('oil') || lower.contains('öl')) return Icons.water_drop_rounded;
    if (lower.contains('wellness') || lower.contains('ayurveda')) return Icons.spa_rounded;
    if (lower.contains('voucher') || lower.contains('gutschein')) return Icons.card_giftcard_rounded;
    return Icons.grass_rounded;
  }

  void _openCategory(BuildContext context, int? categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          user: user ?? const {},
          initialCategoryId: categoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.categories ?? 'Categories',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              GestureDetector(
                onTap: () => _openCategory(context, null),
                child: Text(
                  l10n?.allCategories ?? 'All Categories',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Categories Horizontal Strip
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All Products" tile
                return GestureDetector(
                  onTap: () => _openCategory(context, null),
                  child: SizedBox(
                    width: 68,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1E3325) : const Color(0xFFE8F5E9),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 24,
                            color: isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n?.allProducts ?? 'All',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final cat = categories[index - 1];
              final catId = cat['id'] as int?;
              final catName = cat['name'] as String? ?? 'Category';
              final imageAsset = _categoryImage(catName);

              return GestureDetector(
                onTap: () => _openCategory(context, catId),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.cardColor(context),
                          border: Border.all(
                            color: AppTheme.borderColor(context),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              imageAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  _categoryIcon(catName),
                                  size: 24,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        catName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

