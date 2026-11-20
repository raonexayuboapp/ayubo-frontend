import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class HomeFamilyPromoSection extends StatelessWidget {
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? membership;
  final VoidCallback onExplore;

  const HomeFamilyPromoSection({
    super.key,
    required this.user,
    this.membership,
    required this.onExplore,
  });

  Widget _buildBenefitPill({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.brandGold.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppTheme.brandGold,
              size: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.brandGold.withValues(alpha: isDark ? 0.5 : 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandGold.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          image: const DecorationImage(
            image: AssetImage('assets/images/tea plantation.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark
                    ? const Color(0xFF0B1710).withValues(alpha: 0.94)
                    : AppTheme.emeraldDark.withValues(alpha: 0.93),
                isDark
                    ? const Color(0xFF12241A).withValues(alpha: 0.90)
                    : const Color(0xFF1B4332).withValues(alpha: 0.90),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Ayubo Logo + Gold Tag
              Row(
                children: [
                  Image.asset(
                    'assets/images/Ayubo_logo.png',
                    height: 26,
                    width: 26,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.spa_rounded,
                      color: AppTheme.brandGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.brandGold.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      l10n?.familyPromoTag ?? 'AYUBO FAMILY',
                      style: const TextStyle(
                        color: AppTheme.brandGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                l10n?.familyPromoHeadline ??
                    'Unlock Exclusive Wellness Privileges',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),

              // Benefits
              _buildBenefitPill(
                icon: Icons.account_balance_wallet_outlined,
                text: l10n?.familyBenefitCredit ??
                    '100% shopping credit back on membership',
              ),
              _buildBenefitPill(
                icon: Icons.discount_outlined,
                text: l10n?.familyBenefitDiscount ??
                    'Exclusive member discounts on select organics',
              ),
              _buildBenefitPill(
                icon: Icons.spa_outlined,
                text: l10n?.familyBenefitHeritage ??
                    'Pure Ceylon organic wellness privileges',
              ),
              const SizedBox(height: 14),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onExplore,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    l10n?.exploreAyuboFamily ?? 'Explore Ayubo Family',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandGold,
                    foregroundColor: const Color(0xFF1B4332),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
