import 'package:flutter/material.dart';

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
      autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}