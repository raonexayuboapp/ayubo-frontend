import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/countries.dart';
import '../widgets/loading_button.dart';

class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // null = add, otherwise edit
  final String defaultRecipient;
  const AddressFormScreen({super.key, this.address, this.defaultRecipient = ''});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  final _postalKey = GlobalKey<FormFieldState<String>>();

  late final _recipient = TextEditingController(
      text: (widget.address?['recipient'] as String?) ?? widget.defaultRecipient);
  late final _company = TextEditingController(text: (widget.address?['company'] as String?) ?? '');
  late final _street = TextEditingController(text: (widget.address?['street'] as String?) ?? '');
  late final _line2 = TextEditingController(text: (widget.address?['address_line2'] as String?) ?? '');
  late final _postal = TextEditingController(text: (widget.address?['postal_code'] as String?) ?? '');
  late final _city = TextEditingController(text: (widget.address?['city'] as String?) ?? '');
  late final _region = TextEditingController(text: (widget.address?['region'] as String?) ?? '');

  late String _type = (widget.address?['address_type'] as String?) ?? 'shipping';
  late final String _originalType = _type;
  late String _country = (widget.address?['country_code'] as String?) ?? 'DE';
  late bool _default = widget.address?['is_default'] == true;
  late final bool _wasDefault = _default;

  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.address != null;

  @override
  void dispose() {
    for (final c in [_recipient, _company, _street, _line2, _postal, _city, _region]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- validation (the server checks everything again) ----------

  String? _vRequired(String? v, int max, String label) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > max ? '$label must be 1 to $max characters.' : null;
  }

  String? _vOptional(String? v, int max) => (v ?? '').trim().length > max ? 'Maximum $max characters.' : null;

  String? _vPostal(String? v) {
    final s = normalizePostal(v);
    final country = countryByCode(_country);
    final ok = s.length <= 20 && (country?.postal ?? genericPostal).hasMatch(s);

    if (ok) return null;
    return country?.example == null
        ? 'Enter a valid postal code.'
        : 'Enter a valid postal code, for example ${country!.example}.';
  }

  // ---------- save ----------

  bool _isFieldKey(String k) => const {
    'address_type', 'recipient', 'company', 'street', 'address_line2',
    'postal_code', 'city', 'region', 'country_code', 'is_default',
  }.contains(k);

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    final body = <String, dynamic>{
      'address_type': _type,
      'recipient': _recipient.text.trim(),
      'company': orNull(_company.text),
      'street': _street.text.trim(),
      'address_line2': orNull(_line2.text),
      'postal_code': normalizePostal(_postal.text),
      'city': _city.text.trim(),
      'region': orNull(_region.text),
      'country_code': _country,
      if (_default) 'is_default': true, // "not default" is never sent: the default moves by choosing another one
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
      final errs = e.fieldErrors;
      final general = errs.entries.where((x) => !_isFieldKey(x.key)).map((x) => x.value).join('\n');
      setState(() {
        _serverErrors = errs;
        _error = errs.isEmpty ? e.message : (general.isEmpty ? null : general);
        _saving = false;
      });
    }
  }

  // ---------- UI ----------

  Widget _text(
      String serverKey,
      String label,
      TextEditingController c,
      String? Function(String?) validator, {
        TextInputType? type,
        Key? fieldKey,
        TextCapitalization capitalization = TextCapitalization.words,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: fieldKey,
        controller: c,
        keyboardType: type,
        textCapitalization: capitalization,
        textInputAction: TextInputAction.next,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeChanged = _type != _originalType;
    final countryItems = [
      for (final c in countries) DropdownMenuItem<String>(value: c.code, child: Text('${c.name} (${c.code})')),
      // An address made elsewhere may use a country that is not in our list: keep it selectable.
      if (countryByCode(_country) == null) DropdownMenuItem<String>(value: _country, child: Text(_country)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit address' : 'Add address')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'shipping', label: Text('Shipping'), icon: Icon(Icons.local_shipping_outlined)),
                ButtonSegment(value: 'billing', label: Text('Billing'), icon: Icon(Icons.receipt_long_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                // A moved address never keeps its default flag: it must be chosen again for the new type.
                if (_editing) _default = _type == _originalType ? _wasDefault : false;
              }),
            ),
            if (_serverErrors['address_type'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_serverErrors['address_type']!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 20),
            _text('recipient', 'Recipient', _recipient, (v) => _vRequired(v, 190, 'Recipient')),
            _text('company', 'Company (optional)', _company, (v) => _vOptional(v, 190)),
            _text('street', 'Street and house number', _street, (v) => _vRequired(v, 190, 'Street')),
            _text('address_line2', 'Address line 2 (optional)', _line2, (v) => _vOptional(v, 190)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 2,
                child: _text('postal_code', 'Postal code', _postal, _vPostal,
                    fieldKey: _postalKey, capitalization: TextCapitalization.characters),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _text('city', 'City', _city, (v) => _vRequired(v, 100, 'City'))),
            ]),
            _text('region', 'Region (optional)', _region, (v) => _vOptional(v, 100)),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: _country,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Country', errorText: _serverErrors['country_code']),
                items: countryItems,
                onChanged: (v) {
                  setState(() => _country = v!);
                  _postalKey.currentState?.validate(); // the postal code rule depends on the country
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Use as my default ${_type == 'shipping' ? 'shipping' : 'billing'} address'),
              subtitle: _wasDefault && !typeChanged
                  ? const Text('To change the default, make another address the default.')
                  : null,
              value: _default,
              // The default can only be moved by choosing another address as default.
              onChanged: _wasDefault && !typeChanged ? null : (v) => setState(() => _default = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            LoadingButton(label: 'Save address', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}