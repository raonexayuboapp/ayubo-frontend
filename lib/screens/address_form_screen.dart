import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/loading_button.dart';

class AddressFormScreen extends StatefulWidget {
final Map<String, dynamic>? address;

const AddressFormScreen({
super.key,
this.address,
});

@override
State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
final Map<String, TextEditingController> _controllers = {};

final Map<String, String> _fields = {
'label': 'Address label',
'recipient_name': 'Recipient name',
'line1': 'Address line 1',
'line2': 'Address line 2 (optional)',
'city': 'City',
'district': 'District / Region',
'postal_code': 'Postal code',
};

final Map<String, int> _maxLen = {
'label': 20,
'recipient_name': 190,
'line1': 190,
'line2': 190,
'city': 100,
'district': 100,
'postal_code': 20,
};

final List<Map<String, String>> _countries = [
{'code': 'LK', 'name': 'Sri Lanka'},
{'code': 'DE', 'name': 'Germany'},
{'code': 'IN', 'name': 'India'},
{'code': 'US', 'name': 'United States'},
{'code': 'GB', 'name': 'United Kingdom'},
{'code': 'AU', 'name': 'Australia'},
{'code': 'CA', 'name': 'Canada'},
{'code': 'FR', 'name': 'France'},
{'code': 'IT', 'name': 'Italy'},
{'code': 'JP', 'name': 'Japan'},
{'code': 'SG', 'name': 'Singapore'},
{'code': 'AE', 'name': 'United Arab Emirates'},
];

String _countryCode = 'LK';
bool _default = false;
bool _saving = false;

String? _error;
final Map<String, String> _fieldErrors = {};

bool get _isEditing => widget.address != null;

@override
void initState() {
super.initState();

final address = widget.address;

for (final key in _fields.keys) {
_controllers[key] = TextEditingController(
text: address?[key]?.toString() ?? '',
);
}

final existingCountryCode =
address?['country_code']?.toString().toUpperCase();

if (existingCountryCode != null &&
_countries.any(
(country) => country['code'] == existingCountryCode,
)) {
_countryCode = existingCountryCode;
}

final defaultValue = address?['is_default'];

_default = defaultValue == true ||
defaultValue == 1 ||
defaultValue?.toString() == '1';
}

@override
void dispose() {
for (final controller in _controllers.values) {
controller.dispose();
}

super.dispose();
}

String _fieldLabel(String key) => _fields[key] ?? key;

String? _validateField(String key, String value) {
final trimmed = value.trim();

if (key == 'line2' && trimmed.isEmpty) {
return null;
}

if (trimmed.isEmpty) {
return '${_fieldLabel(key)} is required.';
}

final maxLength = _maxLen[key];

if (maxLength != null && trimmed.length > maxLength) {
return '${_fieldLabel(key)} must not exceed $maxLength characters.';
}

if (key == 'postal_code' &&
!RegExp(r'^[A-Za-z0-9 -]{3,20}$').hasMatch(trimmed)) {
return 'Enter a valid postal code.';
}

return null;
}

bool _validateForm() {
_fieldErrors.clear();

for (final key in _fields.keys) {
final controller = _controllers[key];

if (controller == null) {
_fieldErrors[key] = 'Unable to validate this field.';
continue;
}

final error = _validateField(key, controller.text);

if (error != null) {
_fieldErrors[key] = error;
}
}

if (!_countries.any(
(country) => country['code'] == _countryCode,
)) {
_fieldErrors['country_code'] = 'Please select a country.';
}

return _fieldErrors.isEmpty;
}

Future<void> _save() async {
if (_saving) return;

FocusScope.of(context).unfocus();

if (!_validateForm()) {
setState(() {
_error = 'Please correct the highlighted fields.';
});
return;
}

setState(() {
_saving = true;
_error = null;
_fieldErrors.clear();
});

final Map<String, dynamic> body = {};

for (final key in _fields.keys) {
final controller = _controllers[key];

if (controller == null) {
setState(() {
_saving = false;
_error = 'Unable to read the address form.';
});
return;
}

final value = controller.text.trim();

body[key] = key == 'line2' && value.isEmpty ? null : value;
}

body['country_code'] = _countryCode;
body['is_default'] = _default;

try {
if (_isEditing) {
final id = widget.address?['id'];

if (id == null) {
throw StateError('Address ID is missing.');
}

await ApiService.instance.updateAddress(id, body);
} else {
await ApiService.instance.createAddress(body);
}

if (!mounted) return;

Navigator.of(context).pop(true);
} on ApiException catch (e) {
if (!mounted) return;

setState(() {
_error = e.message;

if (e.fieldErrors != null) {
_fieldErrors.addAll(e.fieldErrors!);
}
});
} catch (_) {
if (!mounted) return;

setState(() {
_error = 'Unable to save the address. Please try again.';
});
} finally {
if (mounted) {
setState(() {
_saving = false;
});
}
}
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);

return Scaffold(
appBar: AppBar(
title: Text(_isEditing ? 'Edit address' : 'Add address'),
),
body: SafeArea(
child: ListView(
padding: const EdgeInsets.all(16),
children: [
if (_error != null)
Container(
padding: const EdgeInsets.all(12),
margin: const EdgeInsets.only(bottom: 16),
decoration: BoxDecoration(
color: theme.colorScheme.errorContainer,
borderRadius: BorderRadius.circular(8),
),
child: Text(
_error!,
style: TextStyle(
color: theme.colorScheme.onErrorContainer,
),
),
),

..._fields.entries.map((entry) {
final key = entry.key;
final label = entry.value;
final isOptional = key == 'line2';

return Padding(
padding: const EdgeInsets.only(bottom: 16),
child: TextFormField(
controller: _controllers[key],
enabled: !_saving,
maxLength: _maxLen[key],
keyboardType: key == 'postal_code'
? TextInputType.text
    : TextInputType.streetAddress,
textCapitalization: key == 'postal_code'
? TextCapitalization.characters
    : TextCapitalization.words,
decoration: InputDecoration(
labelText: label,
border: const OutlineInputBorder(),
errorText: _fieldErrors[key],
counterText: '',
helperText: isOptional ? 'Optional' : null,
),
validator: (value) =>
_validateField(key, value ?? ''),
onChanged: (_) {
if (_fieldErrors.containsKey(key) || _error != null) {
setState(() {
_fieldErrors.remove(key);
_error = null;
});
}
},
),
);
}),

Padding(
padding: const EdgeInsets.only(bottom: 16),
child: DropdownButtonFormField<String>(
initialValue: _countryCode,
isExpanded: true,
decoration: InputDecoration(
labelText: 'Country',
border: const OutlineInputBorder(),
errorText: _fieldErrors['country_code'],
),
items: _countries.map((country) {
return DropdownMenuItem<String>(
value: country['code']!,
child: Text(country['name']!),
);
}).toList(),
onChanged: _saving
? null
    : (value) {
if (value == null) return;

setState(() {
_countryCode = value;
_fieldErrors.remove('country_code');
_error = null;
});
},
),
),

SwitchListTile(
contentPadding: EdgeInsets.zero,
title: const Text('Set as default address'),
value: _default,
onChanged: _saving
? null
    : (value) {
setState(() {
_default = value;
});
},
),

const SizedBox(height: 24),

LoadingButton(
loading: _saving,
onPressed: _save,
label: _isEditing ? 'Save changes' : 'Add address',
),
],
),
),
);
}
}