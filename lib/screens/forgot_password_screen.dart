import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_button.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim();

    try {
      await ApiService.instance.forgotPassword(email);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors['email'] ?? e.message;
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
        title: 'Forgot Password',
        subtitle: 'Account Recovery',
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

          // Main Content
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
                        'Recover Account',
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
                          'Enter your account email and we will send you a 6-digit reset code.',
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
                                // Email Field
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  validator: Validators.email,
                                  onFieldSubmitted: (_) => _submit(),
                                  style: TextStyle(color: scheme.onSurface),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    hintText: 'name@example.com',
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                      color: AppTheme.primaryGreen,
                                      size: 20,
                                    ),
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

                                // Primary CTA
                                LoadingButton(
                                  label: 'Send Reset Code',
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