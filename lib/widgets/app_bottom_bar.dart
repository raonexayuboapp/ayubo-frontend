import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/cart_screen.dart';
import '../screens/family_screen.dart';
import '../screens/products_screen.dart';
import '../services/cart_state.dart';
import '../theme/app_theme.dart';

/// Unified customer navigation bar: Home (0), Shop (1), Family (2), Cart (3).
///
/// Cart is preserved at its designated index 3 with live count badge synchronization.
class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final Map<String, dynamic> user;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.user,
  });

  /// Opens a tab from anywhere in the application.
  /// The navigation stack becomes [Home, tab], ensuring Back always returns to Home.
  static Future<void> open(BuildContext context, int index, Map<String, dynamic> user) async {
    final Widget? screen = switch (index) {
      1 => ProductsScreen(user: user),
      2 => FamilyScreen(user: user),
      3 => CartScreen(user: user),
      _ => null, // 0 = Home, which is the first route
    };

    if (!context.mounted) return;
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _cartIcon(int count, {required bool selected}) {
    final icon = Icon(
      selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
      size: 22,
      color: selected ? AppTheme.primaryGreen : null,
    );
    if (count <= 0) return icon;

    return Badge(
      backgroundColor: AppTheme.brandGold,
      textColor: const Color(0xFF1B4332),
      textStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 10,
        height: 1,
      ),
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<int>(
      valueListenable: CartState.instance.count,
      builder: (context, count, _) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: AppTheme.brandGold.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 64,
              backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
              indicatorColor: AppTheme.brandGold.withValues(alpha: 0.22),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: AppTheme.brandGoldDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  );
                }
                return TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(
                    color: AppTheme.primaryGreen,
                    size: 23,
                  );
                }
                return IconThemeData(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  size: 22,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: currentIndex.clamp(0, 3),
              elevation: 0,
              onDestinationSelected: (i) {
                if (i != currentIndex) open(context, i, user);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l10n?.navHome ?? 'Home',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.storefront_outlined),
                  selectedIcon: const Icon(Icons.storefront_rounded),
                  label: l10n?.navProducts ?? 'Shop',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.card_membership_outlined),
                  selectedIcon: const Icon(Icons.card_membership_rounded),
                  label: l10n?.navFamily ?? 'Family',
                ),
                NavigationDestination(
                  icon: _cartIcon(count, selected: false),
                  selectedIcon: _cartIcon(count, selected: true),
                  label: l10n?.navCart ?? 'Cart',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}