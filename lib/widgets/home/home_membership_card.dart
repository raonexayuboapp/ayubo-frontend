import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/family_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';

class HomeMembershipCard extends StatelessWidget {
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? membership;

  const HomeMembershipCard({
    super.key,
    required this.user,
    this.membership,
  });

  bool get _isMember =>
      membership != null && membership!['status'] == 'active';

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);

    final plan = membership?['plan'] as Map<String, dynamic>?;
    final planName = plan?['name'] as String? ?? (l10n?.activeMember ?? 'Active Member');
    final creditCents = (membership?['credit_cents'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FamilyScreen(
                user: user ?? const {},
                initialSection: 0,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132219) : const Color(0xFFF4F7F4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.brandGold.withValues(alpha: isDark ? 0.45 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGold.withValues(alpha: isDark ? 0.08 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Crest / Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.brandGold.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppTheme.brandGold.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isMember ? Icons.workspace_premium_rounded : Icons.card_membership_rounded,
                  color: AppTheme.brandGoldDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Title & Benefit Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isMember ? planName : (l10n?.familyTitle ?? 'Ayubo Family'),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        if (_isMember) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.brandGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Color(0xFF1B4332),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isMember
                          ? (creditCents != null && creditCents > 0
                              ? '${l10n?.availableCredit ?? 'Credit'}: ${formatCents(creditCents)}'
                              : (l10n?.memberPrivileges ?? 'Active Membership Privileges'))
                          : (l10n?.membershipPromoDesc ??
                              '100% credit back & exclusive member savings'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Action Arrow / Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isMember ? (l10n?.viewDetails ?? 'View') : (l10n?.exploreMembership ?? 'Explore'),
                      style: const TextStyle(
                        color: AppTheme.brandGoldDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppTheme.brandGoldDark,
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

