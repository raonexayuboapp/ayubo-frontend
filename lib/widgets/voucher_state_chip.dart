import 'package:flutter/material.dart';

String voucherStateLabel(String state) {
  switch (state) {
    case 'active':
      return 'Active';
    case 'used':
      return 'Used up';
    case 'expired':
      return 'Expired';
    case 'cancelled':
      return 'Withdrawn';
    default:
      return state.replaceAll('_', ' ');
  }
}

/// A small coloured pill for a voucher's state.
class VoucherStateChip extends StatelessWidget {
  final String state;
  const VoucherStateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    Color background = s.surfaceContainerHighest;
    Color foreground = s.onSurface;
    if (state == 'active') {
      background = s.primaryContainer;
      foreground = s.onPrimaryContainer;
    } else if (state == 'expired' || state == 'cancelled') {
      background = s.errorContainer;
      foreground = s.onErrorContainer;
    }

    return Chip(
      label: Text(voucherStateLabel(state), style: TextStyle(fontSize: 12, color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}