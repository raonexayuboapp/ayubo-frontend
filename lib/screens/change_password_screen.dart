import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/validators.dart';
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
        const SnackBar(content: Text('Password changed. Other devices were logged out.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            PasswordField(
              controller: _current,
              label: 'Current password',
              action: TextInputAction.next,
              serverError: _serverErrors['current_password'],
              validator: (v) => Validators.required(v, 'Current password'),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _new,
              label: 'New password',
              isNew: true,
              action: TextInputAction.next,
              serverError: _serverErrors['new_password'],
              validator: (v) => Validators.password(v, email: widget.email),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              isNew: true,
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              serverError: _serverErrors['new_password_confirmation'],
              validator: (v) => Validators.confirm(v, _new.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            LoadingButton(label: 'Change password', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}