import 'package:flutter/material.dart';

import '../screens/admin_menu_screen.dart';
import '../screens/products_screen.dart';
import '../screens/profile_screen.dart';

/// Search pill + profile icon (+ admin icon for admins).
/// Use it as `appBar:` on the screens that should have it.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onProfileClosed; // lets the screen refresh the user after a profile edit
  final VoidCallback? onSearchTap; // a screen with its own search field handles the tap itself

  const AppTopBar({super.key, required this.user, this.onProfileClosed, this.onSearchTap});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
    );
    onProfileClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onSearchTap ??
                () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductsScreen(user: user, focusSearch: true)),
            ),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text('Search products',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
      actions: [
        if (user['role'] == 'admin')
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Admin',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminMenuScreen(currentUserId: user['id'] as int),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'My profile',
          onPressed: () => _openProfile(context),
        ),
      ],
    );
  }
}