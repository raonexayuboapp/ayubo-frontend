import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/validators.dart';
import '../widgets/loading_button.dart';

class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // null = add, otherwise edit
  const AddressFormScreen({super.key, this.address});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  static const _fields = <(String, String)>[
    ('label', 'Label (e.g. Home, Work)'),
    ('recipient_name', 'Recipient name'),
    ('phone', 'Phone number'),
    ('line1', 'Address line 1'),
    ('line2', 'Address line 2 (optional)'),
    ('city', 'City'),
    ('district', 'District'),
    ('postal_code', 'Postal code'),
  ];

  static const _maxLen = {
    'label': 30,
    'recipient_name': 100,
    'line1': 150,
    'line2': 150,
    'city': 80,
    'district': 80,
  };

  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final f in _fields)
      f.$1: TextEditingController(text: (widget.address?[f.$1] as String?) ?? ''),
  };
  late bool _default = widget.address?['is_default'] == true;
  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.address != null;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(String key, String? v) {
    final s = (v ?? '').trim();
    if (key == 'phone') return Validators.mobile(v);
    if (key == 'postal_code') {
      return RegExp(r'^[A-Za-z0-9 \-]{3,10}$').hasMatch(s) ? null : 'Enter a valid postal code.';
    }
    if (key != 'line2' && s.isEmpty) return 'This field is required.';
    if (s.length > (_maxLen[key] ?? 150)) return 'Maximum ${_maxLen[key]} characters.';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    final body = <String, dynamic>{
      for (final f in _fields) f.$1: _c[f.$1]!.text.trim(),
      'is_default': _default,
    };

    try {
      if (_editing) {
        await ApiService.instance.updateAddress(widget.address!['id'] as int, body);
      } else {
        await ApiService.instance.createAddress(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final wasDefault = widget.address?['is_default'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit address' : 'Add address')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final f in _fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _c[f.$1],
                  keyboardType: f.$1 == 'phone' ? TextInputType.phone : null,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => _validate(f.$1, v),
                  forceErrorText: _serverErrors[f.$1],
                  decoration: InputDecoration(labelText: f.$2),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use as default address'),
              value: _default,
              // The default can only be moved by making another address default.
              onChanged: wasDefault ? null : (v) => setState(() => _default = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            LoadingButton(label: 'Save address', loading: _loading, onPressed: _save),
          ],
        ),
      ),
    );
  }
}