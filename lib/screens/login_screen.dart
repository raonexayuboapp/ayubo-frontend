import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'verify_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnUserOnSuccess;

  const LoginScreen({
    super.key,
    this.returnUserOnSuccess = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      final user = await ApiService.instance.login(email, _password.text);
      if (!mounted) return;
      if (widget.returnUserOnSuccess && Navigator.canPop(context)) {
        Navigator.pop(context, user);
      } else {
        goTo(context, HomeScreen(user: user));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 && e.message == 'Email address is not verified.') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyScreen(
              email: email,
              returnUserOnSuccess: widget.returnUserOnSuccess,
            ),
          ),
        );
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openRegister() async {
    final user = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          returnUserOnSuccess: widget.returnUserOnSuccess,
        ),
      ),
    );
    if (!mounted || user == null) return;
    if (widget.returnUserOnSuccess && Navigator.canPop(context)) {
      Navigator.pop(context, user);
    } else {
      goTo(context, HomeScreen(user: user));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: scheme.onSurface,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Background Ambient Glow Effects
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Gold Logo Branding Container
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(22),
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
                            width: 95,
                            height: 95,
                            fit: BoxFit.contain,
                          ),
                        ).animate().fadeIn(duration: 600.ms).scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.easeOutBack,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Welcome Text
                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 6),

                      Text(
                        'Log in to discover 100% certified organic products',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 250.ms),

                      const SizedBox(height: 32),

                      // Input Form Card
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
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Email Field
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    autofillHints: const [AutofillHints.email],
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    validator: Validators.email,
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
                                  const SizedBox(height: 18),

                                  // Password Field
                                  PasswordField(
                                    controller: _password,
                                    label: 'Password',
                                    action: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                    validator: (v) => Validators.required(v, 'Password'),
                                  ),

                                  // Forgot Password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ForgotPasswordScreen(
                                            initialEmail: _email.text.trim(),
                                          ),
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.brandGoldDark,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),

                                  if (_error != null) ...[
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
                                    const SizedBox(height: 16),
                                  ],

                                  const SizedBox(height: 8),

                                  // Login Button
                                  LoadingButton(
                                    label: 'Log In',
                                    loading: _loading,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: _openRegister,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                            ),
                            child: const Text(
                              'Create an account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 450.ms),

                      if (!canPop) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => goTo(context, const HomeScreen(user: null)),
                            icon: const Icon(Icons.storefront_outlined, size: 18),
                            label: const Text('Continue browsing as guest'),
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
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
