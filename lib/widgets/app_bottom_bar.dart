import 'package:flutter/material.dart';

import '../screens/family_screen.dart';

/// Home, Products, Family, Cart. Use it as `bottomNavigationBar:`.
/// [currentIndex] says which tab the screen belongs to (0 Home, 1 Products, 2 Family, 3 Cart).
class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final Map<String, dynamic> user;
  const AppBottomBar({super.key, required this.currentIndex, required this.user});

  void _onTap(BuildContext context, int i) {
    if (i == currentIndex) return;

    final Widget? screen = switch (i) {
      2 => FamilyScreen(user: user),
      _ => null, // Products and Cart arrive later
    };
    if (i != 0 && screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
      return;
    }

    // Take the navigator first: popping removes this bar's own route, and its context dies with it.
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen));
  }
  // build() stays the same

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _onTap(context, i),
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Products'),
        NavigationDestination(
            icon: Icon(Icons.card_membership_outlined),
            selectedIcon: Icon(Icons.card_membership),
            label: 'Family'),
        NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Cart'),
      ],
    );
  }
}