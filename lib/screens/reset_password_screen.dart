import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    try {
      await ApiService.instance.resetPassword(
        email: widget.email,
        code: _code.text.trim(),
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      goTo(context, const LoginScreen());
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password updated. Please log in.'),
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

  Future<void> _resend() async {
    try {
      await ApiService.instance.forgotPassword(widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If the account exists, a new code was sent.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppHeader(
        title: 'Reset Password',
        subtitle: 'Enter New Password',
        showBackButton: true,
        showProfile: false,
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
                      // Gold Logo Header
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
                        'Create New Password',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Enter the 6-digit verification code sent to ${widget.email} and set your new password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.65),
                            fontSize: 14,
                            height: 1.4,
                          ),
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
                                // 6-Digit Code Field
                                TextFormField(
                                  controller: _code,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    letterSpacing: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  validator: Validators.code,
                                  forceErrorText: _serverErrors['code'],
                                  decoration: InputDecoration(
                                    counterText: '',
                                    labelText: '6-Digit Code',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppTheme.bgDark.withValues(alpha: 0.5)
                                        : AppTheme.bgLight,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: scheme.outline.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryGreen,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // Password Input
                                PasswordField(
                                  controller: _password,
                                  label: 'New password',
                                  isNew: true,
                                  action: TextInputAction.next,
                                  serverError: _serverErrors['password'],
                                  validator: (v) =>
                                      Validators.password(v, email: widget.email),
                                ),

                                const SizedBox(height: 16),

                                // Password Confirmation Input
                                PasswordField(
                                  controller: _confirm,
                                  label: 'Confirm new password',
                                  isNew: true,
                                  action: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  serverError:
                                      _serverErrors['password_confirmation'],
                                  validator: (v) =>
                                      Validators.confirm(v, _password.text),
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

                                // Primary Submit CTA
                                LoadingButton(
                                  label: 'Reset Password',
                                  loading: _loading,
                                  onPressed: _submit,
                                ),

                                const SizedBox(height: 8),

                                // Resend Code Action Button
                                TextButton(
                                  onPressed: _cooldown > 0 ? null : _resend,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.brandGoldDark,
                                  ),
                                  child: Text(
                                    _cooldown > 0
                                        ? 'Resend code in ${_cooldown}s'
                                        : 'Resend code',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _cooldown > 0
                                          ? scheme.onSurface.withValues(alpha: 0.4)
                                          : AppTheme.brandGoldDark,
                                    ),
                                  ),
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