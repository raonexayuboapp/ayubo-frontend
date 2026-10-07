import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/validators.dart';
import '../widgets/loading_button.dart';
import 'addresses_screen.dart';
import 'change_password_screen.dart';
import '../utils/navigation.dart';
import '../widgets/password_field.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();

  late final _first =
  TextEditingController(text: widget.user['first_name'] as String);

  late final _last =
  TextEditingController(text: widget.user['last_name'] as String);

  late final _mobile =
  TextEditingController(text: widget.user['mobile_number'] as String);

  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    try {
      await ApiService.instance.updateProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        mobileNumber: _mobile.text,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved.'),
        ),
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

  Future<void> _confirmDelete() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (deleted == true && mounted) {
      // Take the messenger before navigating away.
      final messenger = ScaffoldMessenger.of(context);

      goTo(context, const LoginScreen());

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account was deleted.'),
        ),
      );
    }
  }

  Widget _field(
      String key,
      String label,
      TextEditingController controller,
      String? Function(String?) validator, {
        TextInputType? type,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        textInputAction: TextInputAction.next,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[key],
        decoration: InputDecoration(
          labelText: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                initialValue: widget.user['email'] as String,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email (cannot be changed)',
                ),
              ),
            ),

            _field(
              'first_name',
              'First name',
              _first,
                  (v) => Validators.name(v, 'First name'),
            ),

            _field(
              'last_name',
              'Last name',
              _last,
                  (v) => Validators.name(v, 'Last name'),
            ),

            _field(
              'mobile_number',
              'Mobile number',
              _mobile,
              Validators.mobile,
              type: TextInputType.phone,
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),

            LoadingButton(
              label: 'Save changes',
              loading: _loading,
              onPressed: _save,
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Saved addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddressesScreen(),
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordScreen(
                    email: widget.user['email'] as String,
                  ),
                ),
              ),
            ),

            const Divider(height: 32),

            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete account',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  bool _loading = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() {
        _fieldError = 'Password is required.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _fieldError = null;
      _error = null;
    });

    try {
      await ApiService.instance.deleteAccount(_password.text);

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _fieldError = e.fieldErrors['password'];
        _error = _fieldError == null ? e.message : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This can't be undone. Your profile and saved addresses "
                "will be removed and you will be logged out. "
                "Enter your password to confirm.",
          ),

          const SizedBox(height: 16),

          PasswordField(
            controller: _password,
            label: 'Password',
            serverError: _fieldError,
            action: TextInputAction.done,
            onSubmitted: (_) => _delete(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: errorColor),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),

        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: errorColor,
          ),
          onPressed: _loading ? null : _delete,
          child: _loading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Delete'),
        ),
      ],
    );
  }
}