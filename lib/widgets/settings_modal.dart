import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../theme/app_theme.dart';

void showAppSettingsModal(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final themeMode = ref.watch(themeProvider);
          final currentLocale = ref.watch(localeProvider);
          final isDarkMode = themeMode == ThemeMode.dark;
          final l10n = AppLocalizations.of(context);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Title Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.brandGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppTheme.brandGoldDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n?.settingsTitle ?? 'App Settings',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Appearance / Theme Toggle
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    l10n?.themeMode ?? 'Theme Mode',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isDarkMode
                        ? (l10n?.themeDark ?? 'Midnight Forest Dark')
                        : (l10n?.themeLight ?? 'Organic Linen Light'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Switch.adaptive(
                    value: isDarkMode,
                    activeThumbColor: AppTheme.brandGold,
                    activeTrackColor: AppTheme.primaryGreen,
                    onChanged: (_) {
                      ref.read(themeProvider.notifier).toggleTheme();
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Language Selection Switcher
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: AppTheme.brandGoldDark,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    l10n?.language ?? (currentLocale.languageCode == 'de' ? 'Sprache' : 'Language'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    currentLocale.languageCode == 'de' ? 'Deutsch' : 'English',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.bgDark
                          : AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.brandGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentLocale.languageCode,
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                        items: const [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'de',
                            child: Text('Deutsch', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                        onChanged: (code) {
                          if (code != null) {
                            ref.read(localeProvider.notifier).setLocale(code);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

