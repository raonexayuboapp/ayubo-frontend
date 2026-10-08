import 'package:flutter/material.dart';

/// Home, Products, Family, Cart. Use it as `bottomNavigationBar:`.
/// [currentIndex] says which tab the screen belongs to (0 Home, 1 Products, 2 Family, 3 Cart).
class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  const AppBottomBar({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int i) {
    if (i == currentIndex) return;

    if (i == 0) {
      // Home is the root screen (login and AuthGate open it with goTo), so "home" = pop back to it.
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    // TODO: when a tab's screen exists, open it here with Navigator.pushReplacement.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

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