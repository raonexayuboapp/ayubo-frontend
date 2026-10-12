import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'address_form_screen.dart';

class AddressesScreen extends StatefulWidget {
const AddressesScreen({super.key});

@override
State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
List<Map<String, dynamic>> _items = [];
bool _loading = true;
bool _deleting = false;
String? _error;

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
if (!mounted) return;

setState(() {
_loading = true;
_error = null;
});

try {
final items = await ApiService.instance.listAddresses();

if (!mounted) return;

setState(() {
_items = items;
_loading = false;
});
} on ApiException catch (e) {
if (!mounted) return;

setState(() {
_error = e.message;
_loading = false;
});
} catch (_) {
if (!mounted) return;

setState(() {
_error = 'Unable to load addresses. Please try again.';
_loading = false;
});
}
}

Future<void> _openForm([Map<String, dynamic>? address]) async {
final saved = await Navigator.push<bool>(
context,
MaterialPageRoute(
builder: (_) => AddressFormScreen(address: address),
),
);

if (saved == true && mounted) {
await _load();
}
}

Future<void> _delete(Map<String, dynamic> address) async {
if (_deleting) return;

final confirmed = await showDialog<bool>(
context: context,
builder: (dialogContext) => AlertDialog(
title: const Text('Delete address?'),
content: Text(
'Remove "${address['label'] ?? 'this address'}" '
'from your saved addresses?',
),
actions: [
TextButton(
onPressed: () => Navigator.pop(dialogContext, false),
child: const Text('Cancel'),
),
TextButton(
onPressed: () => Navigator.pop(dialogContext, true),
child: const Text('Delete'),
),
],
),
);

if (confirmed != true || !mounted) return;

final rawId = address['id'];
final int? id = rawId is int
? rawId
    : int.tryParse(rawId?.toString() ?? '');

if (id == null || id < 1) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Invalid address ID.')),
);
return;
}

setState(() {
_deleting = true;
});

try {
await ApiService.instance.deleteAddress(id);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Address deleted.')),
);

await _load();
} on ApiException catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(e.message)),
);
} catch (_) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Unable to delete the address. Please try again.'),
),
);
} finally {
if (mounted) {
setState(() {
_deleting = false;
});
}
}
}

String _textValue(dynamic value) {
return value?.toString() ?? '';
}

String _addressSummary(Map<String, dynamic> address) {
final recipient = _textValue(address['recipient_name']);
final line1 = _textValue(address['line1']);
final line2 = _textValue(address['line2']);
final city = _textValue(address['city']);
final district = _textValue(address['district']);
final postalCode = _textValue(address['postal_code']);
final countryCode = _textValue(address['country_code']);

final lines = <String>[];

if (recipient.isNotEmpty) {
lines.add(recipient);
}

if (line1.isNotEmpty) {
lines.add(line1);
}

if (line2.isNotEmpty) {
lines.add(line2);
}

final locality = [
city,
district,
postalCode,
].where((part) => part.isNotEmpty).join(', ');

if (locality.isNotEmpty) {
lines.add(locality);
}

if (countryCode.isNotEmpty) {
lines.add(countryCode);
}

return lines.join('\n');
}

bool _isDefault(Map<String, dynamic> address) {
final value = address['is_default'];

return value == true ||
value == 1 ||
value?.toString() == '1';
}

@override
Widget build(BuildContext context) {
Widget body;

if (_loading) {
body = const Center(
child: CircularProgressIndicator(),
);
} else if (_error != null) {
body = Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.error_outline,
size: 40,
),
const SizedBox(height: 12),
Text(
_error!,
textAlign: TextAlign.center,
),
const SizedBox(height: 12),
TextButton(
onPressed: _load,
child: const Text('Retry'),
),
],
),
),
);
} else if (_items.isEmpty) {
body = RefreshIndicator(
onRefresh: _load,
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
children: const [
SizedBox(height: 180),
Icon(
Icons.location_on_outlined,
size: 48,
),
SizedBox(height: 12),
Center(
child: Text('No saved addresses yet.'),
),
],
),
);
} else {
body = RefreshIndicator(
onRefresh: _load,
child: ListView.separated(
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.all(16),
itemCount: _items.length,
separatorBuilder: (_, __) => const SizedBox(height: 8),
itemBuilder: (context, index) {
final address = _items[index];
final label = _textValue(address['label']);
final isDefault = _isDefault(address);

return Card(
child: ListTile(
onTap: _deleting ? null : () => _openForm(address),
title: Row(
children: [
Expanded(
child: Text(
label.isEmpty ? 'Address' : label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
if (isDefault) ...[
const SizedBox(width: 8),
const Chip(
label: Text('Default'),
visualDensity: VisualDensity.compact,
),
],
],
),
subtitle: Padding(
padding: const EdgeInsets.only(top: 6),
child: Text(_addressSummary(address)),
),
isThreeLine: true,
trailing: IconButton(
icon: const Icon(Icons.delete_outline),
tooltip: 'Delete address',
onPressed:
_deleting ? null : () => _delete(address),
),
),
);
},
),
);
}

return Scaffold(
appBar: AppBar(
title: const Text('Saved addresses'),
),
body: body,
floatingActionButton: FloatingActionButton.extended(
onPressed: _loading || _deleting ? null : () => _openForm(),
icon: const Icon(Icons.add),
label: const Text('Add address'),
),
);
}
}