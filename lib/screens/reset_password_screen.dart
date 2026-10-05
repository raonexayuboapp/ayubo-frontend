import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
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
      messenger.showSnackBar(const SnackBar(content: Text('Password updated. Please log in.')));
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
        const SnackBar(content: Text('If the account exists, a new code was sent.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Enter the 6-digit code sent to ${widget.email} and choose a new password.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: Validators.code,
              forceErrorText: _serverErrors['code'],
              decoration: const InputDecoration(counterText: '', labelText: 'Reset code'),
            ),
            const SizedBox(height: 8),
            PasswordField(
              controller: _password,
              label: 'New password',
              isNew: true,
              action: TextInputAction.next,
              serverError: _serverErrors['password'],
              validator: (v) => Validators.password(v, email: widget.email),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              isNew: true,
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              serverError: _serverErrors['password_confirmation'],
              validator: (v) => Validators.confirm(v, _password.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            LoadingButton(label: 'Reset password', loading: _loading, onPressed: _submit),
            TextButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}