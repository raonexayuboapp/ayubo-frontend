import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class HomeTrustFooter extends StatelessWidget {
  const HomeTrustFooter({super.key});

  Widget _buildBadge(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppTheme.brandGoldDark,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trust Badges Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildBadge(
                context,
                Icons.verified_outlined,
                isDe ? '100% Bio' : '100% Organic',
              ),
              _buildBadge(
                context,
                Icons.handshake_outlined,
                isDe ? 'Fairer Handel' : 'Fair Trade',
              ),
              _buildBadge(
                context,
                Icons.local_shipping_outlined,
                isDe ? 'EU-zertifiziert' : 'EU Certified',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Heritage Tagline
          Text(
            l10n?.pureCeylonHeritage ?? '100% Certified Organic • Ceylon Heritage',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary(context).withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),

          // Copyright
          Text(
            '© ${DateTime.now().year} Ayubo Organics',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

