import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../compact_product_card.dart';

typedef ProductData = Map<String, dynamic>;

class HomeBestSellersSection extends StatelessWidget {
  final List<ProductData> products;
  final Map<String, dynamic>? user;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;

  const HomeBestSellersSection({
    super.key,
    required this.products,
    required this.user,
    this.loading = false,
    this.error,
    required this.onRetry,
    required this.onViewAll,
  });

  Widget _buildSkeleton(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final shimmerColor = isDark
        ? const Color(0xFF1B2A20)
        : const Color(0xFFE8ECE8);

    return SizedBox(
      height: 268,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Container(
            width: 168,
            decoration: AppTheme.cardDecoration(context, radius: 16),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 110,
                  height: 12,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 14,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context, radius: 14),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: isDark ? AppTheme.brandGoldLight : AppTheme.brandGoldDark,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error ?? (l10n?.retry ?? 'Could not load bestsellers.'),
                style: AppTheme.captionStyle(context),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryAction(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: Text(l10n?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // If completely empty and not loading or error, hide section gracefully
    if (!loading && error == null && products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.bestsellers ?? 'Best Sellers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n?.bestsellersSubtitle ??
                          'Customer favorites & organic essentials',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.descriptionStyle(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n?.viewAll ?? 'View All',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        if (loading)
          _buildSkeleton(context)
        else if (error != null)
          _buildError(context)
        else
          SizedBox(
            height: 268,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final product = products[index];
                return CompactProductCard(
                  product: product,
                  user: user,
                  width: 168,
                );
              },
            ),
          ),
      ],
    );
  }
}
