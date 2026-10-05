import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/validators.dart';
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Enter your account email and we will send you a 6-digit reset code.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            LoadingButton(label: 'Send reset code', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}