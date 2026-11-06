import 'package:flutter/material.dart';
import '../utils/money.dart';

String voucherStateLabel(String state, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  if (loc.startsWith('de')) {
    switch (state) {
      case 'active':
        return 'Aktiv';
      case 'used':
        return 'Eingelöst';
      case 'expired':
        return 'Abgelaufen';
      case 'cancelled':
        return 'Storniert';
      default:
        return state.replaceAll('_', ' ');
    }
  }
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

String voucherKindLabel(String kind, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  if (loc.startsWith('de')) {
    switch (kind) {
      case 'issued':
        return 'Vom Personal ausgestellt';
      case 'purchased':
        return 'Im Shop gekauft';
      case 'membership_credit':
        return 'Mitgliedschaftsguthaben';
      default:
        return kind.replaceAll('_', ' ');
    }
  }
  switch (kind) {
    case 'issued':
      return 'Issued by staff';
    case 'purchased':
      return 'Bought in the shop';
    case 'membership_credit':
      return 'Membership credit';
    default:
      return kind.replaceAll('_', ' ');
  }
}

/// A small coloured pill for a voucher's state.
class VoucherStateChip extends StatelessWidget {
  final String state;
  const VoucherStateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (background, foreground) = switch (state) {
      'active' => (
          Colors.green.shade600.withValues(alpha: isDark ? 0.2 : 0.12),
          isDark ? Colors.green.shade400 : Colors.green.shade700,
        ),
      'expired' || 'cancelled' => (
          theme.colorScheme.error.withValues(alpha: 0.12),
          theme.colorScheme.error,
        ),
      _ => (
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: foreground.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        voucherStateLabel(state),
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
