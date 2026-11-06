import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/family_screen.dart';
import '../../theme/app_theme.dart';

class HomePromoBanner extends StatelessWidget {
  final Map<String, dynamic>? user;

  const HomePromoBanner({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FamilyScreen(
                user: user ?? const {},
                initialSection: 1, // Opens Gift Vouchers section directly
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132018) : const Color(0xFFF2F6F3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.brandGold.withValues(alpha: isDark ? 0.4 : 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGold.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Content Side
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.brandGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isDe ? 'GUTSCHEINE' : 'WELLNESS GIFTING',
                          style: const TextStyle(
                            color: AppTheme.brandGoldDark,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Title
                      Text(
                        l10n?.giftVoucherPromoTitle ?? 'Gift of Pure Wellness',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Subtitle
                      Text(
                        l10n?.giftVoucherPromoSubtitle ??
                            'Digital vouchers delivered instantly by email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // CTA Link
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n?.sendVoucher ?? 'Send Voucher',
                            style: const TextStyle(
                              color: AppTheme.brandGoldDark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: AppTheme.brandGoldDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Image Thumbnail Side
              SizedBox(
                width: 100,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/harmonie_set_for_her.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          size: 32,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            isDark ? const Color(0xFF132018) : const Color(0xFFF2F6F3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

