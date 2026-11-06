import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? serverError;
  final bool isNew; // new-password field (autofill offers to save it)
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.serverError,
    this.isNew = false,
    this.action,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.action,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      forceErrorText: widget.serverError,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofillHints: [
        widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      style: TextStyle(color: scheme.onSurface),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppTheme.primaryGreen,
          size: 20,
        ),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: scheme.onSurfaceVariant,
            size: 20,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}