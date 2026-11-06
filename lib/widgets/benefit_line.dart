import 'package:flutter/material.dart';

typedef BenefitData = Map<String, dynamic>;

IconData benefitIcon(String kind) => switch (kind) {
      'credit' => Icons.account_balance_wallet_outlined,
      'discount' => Icons.sell_outlined,
      _ => Icons.check_circle_outline,
    };

/// One benefit as a member reads it: an icon for its kind and the text. Credit and discount lines are bold.
class BenefitLine extends StatelessWidget {
  final BenefitData benefit;
  final Color? color;

  const BenefitLine({super.key, required this.benefit, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final kind = benefit['kind'] as String;
    final iconColor = color ?? goldColor;
    final isSpecial = kind != 'perk';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              benefitIcon(kind),
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                benefit['description'] as String,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSpecial ? FontWeight.w600 : FontWeight.normal,
                  color: isSpecial
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}