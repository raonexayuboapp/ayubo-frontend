import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String email;
  const ChangePasswordScreen({super.key, required this.email});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    try {
      await ApiService.instance.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
        newPasswordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password changed. Other devices were logged out.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppHeader(
        title: 'Change Password',
        subtitle: 'Account Security',
        showBackButton: true,
      ),
      body: Stack(
        children: [
          // Ambient Glow Background Effects
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandGold.withValues(alpha: isDark ? 0.12 : 0.07),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Gold Logo Branding Header
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppTheme.surfaceDark : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.brandGold.withValues(alpha: 0.35),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(
                              color: AppTheme.brandGold.withValues(alpha: 0.7),
                              width: 2,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/Ayubo_logo.png',
                            width: 85,
                            height: 85,
                            fit: BoxFit.contain,
                          ),
                        ).animate().fadeIn(duration: 600.ms).scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.easeOutBack,
                            ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Update Security',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 6),

                      Text(
                        'Ensure your account remains safe with a robust password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 250.ms),

                      const SizedBox(height: 28),

                      // Form Container Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            width: 1,
                          ),
                        ),
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Current Password Field
                                PasswordField(
                                  controller: _current,
                                  label: 'Current password',
                                  action: TextInputAction.next,
                                  serverError: _serverErrors['current_password'],
                                  validator: (v) =>
                                      Validators.required(v, 'Current password'),
                                ),

                                const SizedBox(height: 18),

                                // New Password Field
                                PasswordField(
                                  controller: _new,
                                  label: 'New password',
                                  isNew: true,
                                  action: TextInputAction.next,
                                  serverError: _serverErrors['new_password'],
                                  validator: (v) =>
                                      Validators.password(v, email: widget.email),
                                ),

                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 6,
                                    bottom: 16,
                                  ),
                                  child: Text(
                                    '8+ characters with at least one letter and one number.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                ),

                                // Confirm Password Field
                                PasswordField(
                                  controller: _confirm,
                                  label: 'Confirm new password',
                                  isNew: true,
                                  action: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  serverError:
                                      _serverErrors['new_password_confirmation'],
                                  validator: (v) =>
                                      Validators.confirm(v, _new.text),
                                ),

                                // Error Banner
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: scheme.error.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          size: 18,
                                          color: scheme.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: scheme.error,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 24),

                                LoadingButton(
                                  label: 'Change Password',
                                  loading: _loading,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}