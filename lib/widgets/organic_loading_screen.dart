import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class OrganicLoadingScreen extends StatelessWidget {
  final String? message;
  final double logoSize;

  const OrganicLoadingScreen({
    super.key,
    this.message,
    this.logoSize = 110.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background Organic Ambient Glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandGold.withValues(alpha: isDark ? 0.12 : 0.06),
              ),
            ),
          ),

          // Main Loader Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gold Logo Card with Halo Effect
                  Container(
                    padding: EdgeInsets.all(logoSize * 0.2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandGold.withValues(alpha: 0.35),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.brandGold.withValues(alpha: 0.6),
                        width: 1.8,
                      ),
                    ),
                    child: Image.asset(
                      'assets/images/Ayubo_logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.eco_rounded,
                        size: logoSize,
                        color: AppTheme.brandGold,
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scaleXY(
                        begin: 0.96,
                        end: 1.04,
                        duration: 1800.ms,
                        curve: Curves.easeInOut,
                      ),

                  const SizedBox(height: 36),

                  // Dual Green & Gold Circular Progress Indicator
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.2,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandGold),
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Loading Text / Brand Subtitle
                  Text(
                    message ?? 'Ayubo Organics',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),

                  const SizedBox(height: 8),

                  Text(
                    '100% Pure & Certified',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}