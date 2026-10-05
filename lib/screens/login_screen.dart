import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'verify_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      goTo(context, HomeScreen(user: user));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyScreen(email: email)));
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: Form(
        key: _form,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: Validators.email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Password',
                action: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => Validators.required(v, 'Password'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              LoadingButton(label: 'Log in', loading: _loading, onPressed: _submit),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}