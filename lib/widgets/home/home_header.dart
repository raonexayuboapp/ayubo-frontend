import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/admin_menu_screen.dart';
import '../../screens/profile_screen.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_prompt_dialog.dart';

class HomeHeader extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onProfileClosed;
  final VoidCallback onOpenSettings;

  const HomeHeader({
    super.key,
    required this.user,
    required this.onProfileClosed,
    required this.onOpenSettings,
  });

  bool get _isGuest => user == null;

  String _greetingText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? (l10n?.greetingMorning ?? 'Good morning')
        : (hour < 17
            ? (l10n?.greetingAfternoon ?? 'Good afternoon')
            : (l10n?.greetingEvening ?? 'Good evening'));

    final firstName = user?['first_name'] as String?;
    if (firstName != null && firstName.trim().isNotEmpty) {
      return '$greeting, ${firstName.trim()}';
    }
    return l10n?.welcomeGuest ?? 'Welcome to Ayubo Organics';
  }

  Future<void> _handleProfileTap(BuildContext context) async {
    if (_isGuest && !await ApiService.instance.hasToken()) {
      if (!context.mounted) return;
      final loggedUser = await showAuthPrompt(
        context,
        title: 'Ayubo Account',
        message: 'Sign in or create an account to view your profile, manage addresses, and check order history.',
      );
      if (loggedUser == null || !context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(user: loggedUser)),
      );
      onProfileClosed();
      return;
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(user: user ?? const {})),
    );
    onProfileClosed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Row(
          children: [
            // Brand Logo & Greeting Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                      const SizedBox(width: 8),
                      Text(
                        'Ayubo Organics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _greetingText(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Header Actions: Admin, Settings, Cart, Profile
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user?['role'] == 'admin') ...[
                  IconButton(
                    tooltip: 'Admin Panel',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 22,
                      color: AppTheme.brandGoldDark,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminMenuScreen(
                            currentUserId: user?['id'] as int? ?? 0,
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // Settings icon
                IconButton(
                  tooltip: l10n?.settingsTitle ?? 'Settings',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 21,
                    color: AppTheme.textSecondary(context),
                  ),
                  onPressed: onOpenSettings,
                ),

                const SizedBox(width: 4),

                // Profile Avatar / Icon
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
                      color: _isGuest ? scheme.onSurface.withValues(alpha: 0.6) : AppTheme.primaryGreen,
                    ),
                  ),
                  onPressed: () => _handleProfileTap(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

