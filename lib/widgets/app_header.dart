import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/admin_menu_screen.dart';
import '../screens/profile_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'auth_prompt_dialog.dart';
import 'settings_modal.dart';

/// Reusable application-wide top app bar following the Ayubo Organics design system.
///
/// Features consistent branding, logo, typography, height, theme behavior, and
/// screen-specific back navigation and actions.
///
/// Note: The shopping cart destination is located in the bottom navigation bar;
/// it is intentionally omitted here to prevent duplicate cart icons.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Map<String, dynamic>? user;
  final bool? showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showSettings;
  final bool showProfile;
  final bool showAdmin;
  final VoidCallback? onProfileClosed;
  final PreferredSizeWidget? bottom;
  final Widget? titleWidget;

  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.user,
    this.showBackButton,
    this.onBack,
    this.actions,
    this.showSettings = true,
    this.showProfile = true,
    this.showAdmin = true,
    this.onProfileClosed,
    this.bottom,
    this.titleWidget,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        60.0 + (bottom?.preferredSize.height ?? 0.0),
      );

  bool get _isGuest => user == null || user!.isEmpty;

  Future<void> _openProfile(BuildContext context) async {
    if (_isGuest && !await ApiService.instance.hasToken()) {
      if (!context.mounted) return;
      final loggedUser = await showAuthPrompt(
        context,
        title: 'Ayubo Account',
        message:
            'Sign in or create an account to view your profile, manage addresses, check orders, and track loyalty points.',
      );
      if (loggedUser == null || !context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(user: loggedUser)),
      );
      onProfileClosed?.call();
      return;
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(user: user ?? const {})),
    );
    onProfileClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final canPop = showBackButton ?? (Navigator.canPop(context));

    Widget leadingOrTitle;
    if (titleWidget != null) {
      leadingOrTitle = titleWidget!;
    } else if (canPop) {
      leadingOrTitle = Row(
        children: [
          InkWell(
            onTap: onBack ?? () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ?? 'Ayubo Organics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Root screen with brand logo
      leadingOrTitle = Row(
        children: [
          Image.asset(
            'assets/images/Ayubo_logo.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.spa_rounded,
              size: 24,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ?? 'Ayubo Organics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle ?? (l10n?.familySubtitle ?? 'Pure Organic Ceylon Botanicals'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      shape: Border(
        bottom: BorderSide(
          color: AppTheme.borderColor(context).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      title: leadingOrTitle,
      actions: [
        if (actions != null) ...actions!,
        if (showAdmin && user?['role'] == 'admin') ...[
          IconButton(
            tooltip: 'Admin Panel',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.admin_panel_settings_outlined,
              size: 21,
              color: AppTheme.brandGoldDark,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminMenuScreen(
                    currentUserId: (user?['id'] as num?)?.toInt() ?? 0,
                  ),
                ),
              );
            },
          ),
        ],
        if (showSettings)
          IconButton(
            tooltip: l10n?.settingsTitle ?? 'Settings',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: AppTheme.textSecondary(context),
            ),
            onPressed: () => showAppSettingsModal(context),
          ),
        if (showProfile) ...[
          const SizedBox(width: 2),
          IconButton(
            tooltip: l10n?.navProfile ?? 'Profile',
            visualDensity: VisualDensity.compact,
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardSubtleColor(context),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                  width: 1.2,
                ),
              ),
              child: Icon(
                _isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
                size: 18,
                color: _isGuest
                    ? AppTheme.textSecondary(context)
                    : (isDark ? AppTheme.leafGreen : AppTheme.primaryGreen),
              ),
            ),
            onPressed: () => _openProfile(context),
          ),
        ],
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}

