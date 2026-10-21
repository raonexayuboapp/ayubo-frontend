import 'package:flutter/material.dart';

IconData benefitIcon(String kind) => switch (kind) {
  'credit' => Icons.account_balance_wallet_outlined,
  'discount' => Icons.sell_outlined,
  _ => Icons.check_circle_outline,
};

/// One benefit as a member reads it: an icon for its kind and the text. Credit and discount lines are bold.
class BenefitLine extends StatelessWidget {
  final Map<String, dynamic> benefit;
  final Color? color;

  const BenefitLine({super.key, required this.benefit, this.color});

  @override
  Widget build(BuildContext context) {
    final kind = benefit['kind'] as String;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(benefitIcon(kind), size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          benefit['description'] as String,
          style: kind == 'perk' ? null : const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ]);
  }
}