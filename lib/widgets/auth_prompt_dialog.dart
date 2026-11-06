import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/app_localizations.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../theme/app_theme.dart';

/// Displays a themed Emerald Green & Metallic Gold bottom sheet prompting the customer to log in or register.
///
/// Returns the authenticated [Map<String, dynamic>] if the user logged in, or `null` if cancelled.
Future<Map<String, dynamic>?> showAuthPrompt(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AuthPromptSheet(
      title: title,
      message: message,
    ),
  );
}

class AuthPromptSheet extends StatelessWidget {
  final String title;
  final String message;

  const AuthPromptSheet({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Brand Halo Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                border: Border.all(
                  color: AppTheme.brandGold.withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandGold.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                size: 38,
                color: AppTheme.brandGoldDark,
              ),
            ).animate().scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Descriptive Message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Option 1: Log In (Primary Button)
          ElevatedButton.icon(
            onPressed: () async {
              final user = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(returnUserOnSuccess: true),
                ),
              );
              if (user != null && context.mounted) {
                Navigator.pop(context, user);
              }
            },
            icon: const Icon(Icons.login_rounded, size: 20),
            label: Text(
              l10n?.signIn ?? 'Log In',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: AppTheme.brandGold,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.brandGold.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Option 2: Create Account / Register (Secondary Button)
          OutlinedButton.icon(
            onPressed: () async {
              final user = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterScreen(returnUserOnSuccess: true),
                ),
              );
              if (user != null && context.mounted) {
                Navigator.pop(context, user);
              }
            },
            icon: const Icon(Icons.person_add_outlined, size: 20),
            label: Text(
              l10n?.register ?? 'Create an Account',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: AppTheme.brandGold.withValues(alpha: 0.6),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Option 3: Cancel / Continue Browsing (Dismiss Button)
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(
              l10n?.cancelAndContinueBrowsing ?? 'Cancel and continue browsing',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

