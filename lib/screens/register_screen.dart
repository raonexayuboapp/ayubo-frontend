import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';
import 'verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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
      goTo(context, VerifyScreen(email: email));
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
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        autofillHints: hints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[key],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Form(
        key: _form,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _text('first_name', 'First name', _first, (v) => Validators.name(v, 'First name'),
                  hints: const [AutofillHints.givenName]),
              _text('last_name', 'Last name', _last, (v) => Validators.name(v, 'Last name'),
                  hints: const [AutofillHints.familyName]),
              _text('mobile_number', 'Mobile number', _mobile, Validators.mobile,
                  type: TextInputType.phone, hints: const [AutofillHints.telephoneNumber]),
              _text('email', 'Email', _email, Validators.email,
                  type: TextInputType.emailAddress, hints: const [AutofillHints.email]),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: PasswordField(
                  controller: _password,
                  label: 'Password',
                  isNew: true,
                  action: TextInputAction.next,
                  serverError: _serverErrors['password'],
                  validator: (v) => Validators.password(v, email: _email.text),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 12),
                child: Text(
                  '8+ characters with at least one letter and one number.',
                  style: Theme.of(context).textTheme.bodySmall,
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
                  serverError: _serverErrors['password_confirmation'],
                  validator: (v) => Validators.confirm(v, _password.text),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              LoadingButton(label: 'Register', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}