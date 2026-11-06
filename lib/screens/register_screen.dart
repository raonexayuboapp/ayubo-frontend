import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';
import 'verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool returnUserOnSuccess;

  const RegisterScreen({
    super.key,
    this.returnUserOnSuccess = false,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final c in [_first, _last, _mobile, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    final email = _email.text.trim();

    try {
      await ApiService.instance.register(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        mobileNumber: _mobile.text,
        email: email,
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      if (widget.returnUserOnSuccess && Navigator.canPop(context)) {
        final user = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyScreen(
              email: email,
              returnUserOnSuccess: true,
            ),
          ),
        );
        if (user != null && mounted) {
          Navigator.pop(context, user);
        }
      } else {
        goTo(context, VerifyScreen(email: email));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _loading = false;
      });
    }
  }

  Widget _text(
    String key,
    String label,
    TextEditingController c,
    String? Function(String?) validator, {
    TextInputType? type,
    List<String>? hints,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        autofillHints: hints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[key],
        style: TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 20,
                )
              : null,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppHeader(
        title: 'Create Account',
        subtitle: 'Join Ayubo Organics',
        showBackButton: true,
        showProfile: false,
      ),
      body: Stack(
        children: [
          // Background Ambient Glow Effects
          Positioned(
            top: -100,
            right: -80,
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
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandGold.withValues(alpha: isDark ? 0.12 : 0.07),
              ),
            ),
          ),

          // Main Form Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Gold Logo Branding Container
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

                      // Section Header
                      Text(
                        'Join Ayubo Organics',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 6),

                      Text(
                        'Create an account to start shopping pure organic goods',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 14,
                        ),
                      ).animate().fadeIn(delay: 250.ms),

                      const SizedBox(height: 28),

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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _text(
                                          'first_name',
                                          'First name',
                                          _first,
                                          (v) => Validators.name(v, 'First name'),
                                          hints: const [AutofillHints.givenName],
                                          icon: Icons.person_outline_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _text(
                                          'last_name',
                                          'Last name',
                                          _last,
                                          (v) => Validators.name(v, 'Last name'),
                                          hints: const [AutofillHints.familyName],
                                        ),
                                      ),
                                    ],
                                  ),
                                  _text(
                                    'mobile_number',
                                    'Mobile number',
                                    _mobile,
                                    Validators.mobile,
                                    type: TextInputType.phone,
                                    hints: const [AutofillHints.telephoneNumber],
                                    icon: Icons.phone_outlined,
                                  ),
                                  _text(
                                    'email',
                                    'Email address',
                                    _email,
                                    Validators.email,
                                    type: TextInputType.emailAddress,
                                    hints: const [AutofillHints.email],
                                    icon: Icons.email_outlined,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: PasswordField(
                                      controller: _password,
                                      label: 'Password',
                                      isNew: true,
                                      action: TextInputAction.next,
                                      serverError: _serverErrors['password'],
                                      validator: (v) =>
                                          Validators.password(v, email: _email.text),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16,
                                      left: 8,
                                      top: 4,
                                    ),
                                    child: Text(
                                      '8+ characters with at least one letter and one number.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: PasswordField(
                                      controller: _confirm,
                                      label: 'Confirm password',
                                      isNew: true,
                                      action: TextInputAction.done,
                                      onSubmitted: (_) => _submit(),
                                      serverError:
                                          _serverErrors['password_confirmation'],
                                      validator: (v) =>
                                          Validators.confirm(v, _password.text),
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
                                  LoadingButton(
                                    label: 'Register Account',
                                    loading: _loading,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
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
