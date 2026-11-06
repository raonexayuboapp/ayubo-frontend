import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'app_header.dart';

import '../l10n/app_localizations.dart';
import 'settings_modal.dart';
import '../screens/admin_menu_screen.dart';
import '../screens/products_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

import '../services/api_service.dart';
import 'auth_prompt_dialog.dart';

class AppTopBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onProfileClosed;

  /// Updates the existing catalogue when searching from ProductsScreen.
  final ValueChanged<String>? onSearchSubmitted;

  /// Initial query when opening ProductsScreen from another page.
  final String initialSearch;

  const AppTopBar({
    super.key,
    required this.user,
    this.onProfileClosed,
    this.onSearchSubmitted,
    this.initialSearch = '',
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends ConsumerState<AppTopBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: widget.initialSearch,
    );

    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant AppTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialSearch != widget.initialSearch &&
        _searchController.text != widget.initialSearch) {
      _searchController.text = widget.initialSearch;
    }
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

Future<void> _openProfile() async {
  // Guest users must authenticate before accessing their profile.
  if (widget.user.isEmpty && !await ApiService.instance.hasToken()) {
    if (!mounted) return;
    final user = await showAuthPrompt(
      context,
      title: 'Ayubo Account',
      message: 'Log in or create an account to view your profile, manage addresses, check orders, and track loyalty points.',
    );

    if (user == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: user),
      ),
    );

    if (mounted) {
      widget.onProfileClosed?.call();
    }
    return;
  }

  if (!mounted) return;

  // Authenticated users can access their profile.
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileScreen(user: widget.user),
    ),
  );

  if (mounted) {
    widget.onProfileClosed?.call();
  }
}

  void _submitSearch(String value) {
    final query = value.trim();

    // Update the current catalogue instead of opening another
    // ProductsScreen when the search originates there.
    if (widget.onSearchSubmitted != null) {
      widget.onSearchSubmitted!(query);
      return;
    }

    // Open the catalogue with the submitted query from other pages.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          user: widget.user,
          initialSearch: query,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();

    // If already on ProductsScreen, immediately reset the catalogue.
    widget.onSearchSubmitted?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      elevation: 0,
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      title: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.brandGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandGold.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: l10n?.searchHint ?? 'Search organic products...',
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                tooltip: l10n?.close ?? 'Clear search',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: _clearSearch,
              ),
          ],
        ),
      ),
      actions: [
        if (widget.user['role'] == 'admin')
          IconButton(
            icon: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppTheme.brandGoldDark,
            ),
            tooltip: 'Admin Panel',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminMenuScreen(
                    currentUserId: widget.user['id'] as int,
                  ),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: AppTheme.primaryGreen,
          ),
          tooltip: l10n?.settingsTitle ?? 'App Settings',
          onPressed: () => showAppSettingsModal(context),
        ),
        IconButton(
          icon: const Icon(
            Icons.person_outline_rounded,
            color: AppTheme.primaryGreen,
          ),
          tooltip: l10n?.myProfile ?? 'My Profile',
          onPressed: _openProfile,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}