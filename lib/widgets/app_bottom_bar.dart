import 'package:flutter/material.dart';

import '../screens/cart_screen.dart';
import '../screens/family_screen.dart';
import '../screens/products_screen.dart';
import '../services/cart_state.dart';

/// Home, Products, Family, Cart. Use it as `bottomNavigationBar:`.
/// [currentIndex] says which tab the screen belongs to (0 Home, 1 Products, 2 Family, 3 Cart).
class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final Map<String, dynamic> user;
  const AppBottomBar({super.key, required this.currentIndex, required this.user});

  /// Opens a tab from anywhere. The stack becomes [Home, tab], so Back always returns to Home.
  static void open(BuildContext context, int index, Map<String, dynamic> user) {
    final Widget? screen = switch (index) {
      1 => ProductsScreen(user: user),
      2 => FamilyScreen(user: user),
      3 => CartScreen(user: user),
      _ => null, // 0 = Home, which is the first route
    };

    // Take the navigator first: popping removes the calling screen, and its context dies with it.
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _cartIcon(int count, {required bool selected}) {
    final icon = Icon(selected ? Icons.shopping_cart : Icons.shopping_cart_outlined);
    if (count <= 0) return icon;

    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CartState.instance.count,
      builder: (context, count, _) => NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          if (i != currentIndex) open(context, i, user);
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Products'),
          const NavigationDestination(
              icon: Icon(Icons.card_membership_outlined), selectedIcon: Icon(Icons.card_membership), label: 'Family'),
          NavigationDestination(
            icon: _cartIcon(count, selected: false),
            selectedIcon: _cartIcon(count, selected: true),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}