import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class HomeShopExperienceSection extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onExploreProducts;

  const HomeShopExperienceSection({
    super.key,
    required this.user,
    required this.onExploreProducts,
  });

  Widget _buildFeatureChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primaryGreen.withValues(alpha: 0.15)
            : const Color(0xFFEBF3ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: AppTheme.cardDecoration(context, radius: 20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Header with Boutique Badge
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/spices 1.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 40,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  // Dark gradient overlay for badge readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldDark.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.brandGold.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.brandGold,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n?.experienceAyuboTag ?? 'OUR PHYSICAL BOUTIQUE',
                            style: const TextStyle(
                              color: AppTheme.brandGold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.experienceAyubo ?? 'Experience Ayubo Organics',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n?.experienceAyuboSubtitle ??
                        'Visit our physical store to experience pure Ceylon organic spices, wellness teas, and Ayurvedic traditions in person.',
                    style: AppTheme.descriptionStyle(context),
                  ),
                  const SizedBox(height: 14),

                  // Feature Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip(
                        context,
                        icon: Icons.eco_outlined,
                        label: l10n?.shopFeatureOrganic ??
                            '100% Certified Organic',
                      ),
                      _buildFeatureChip(
                        context,
                        icon: Icons.handshake_outlined,
                        label: l10n?.shopFeatureFairTrade ??
                            'Direct Fair Trade',
                      ),
                      _buildFeatureChip(
                        context,
                        icon: Icons.spa_outlined,
                        label: l10n?.shopFeatureAuthentic ??
                            'Authentic Ceylon Heritage',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action to explore the store collection
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onExploreProducts,
                      icon: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                      ),
                      label: Text(
                        l10n?.exploreStoreCollection ??
                            'Explore In-Store Collection',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? AppTheme.brandGoldLight
                            : AppTheme.primaryGreen,
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.brandGold.withValues(alpha: 0.5)
                              : AppTheme.primaryGreen.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
