import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/validators.dart';
import '../widgets/loading_button.dart';
import 'addresses_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.user['first_name'] as String);
  late final _last = TextEditingController(text: widget.user['last_name'] as String);
  late final _mobile = TextEditingController(text: widget.user['mobile_number'] as String);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _loading = false;
      });
    }
  }

  Widget _field(String key, String label, TextEditingController c,
      String? Function(String?) validator, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        textInputAction: TextInputAction.next,
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
      appBar: AppBar(title: const Text('My profile')),
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
                decoration: const InputDecoration(labelText: 'Email (cannot be changed)'),
              ),
            ),
            _field('first_name', 'First name', _first, (v) => Validators.name(v, 'First name')),
            _field('last_name', 'Last name', _last, (v) => Validators.name(v, 'Last name')),
            _field('mobile_number', 'Mobile number', _mobile, Validators.mobile,
                type: TextInputType.phone),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            LoadingButton(label: 'Save changes', loading: _loading, onPressed: _save),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Saved addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordScreen(email: widget.user['email'] as String),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}