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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    }
  }

  Future<void> _openForm([Map<String, dynamic>? address]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddressFormScreen(address: address)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove "${a['label']}" from your saved addresses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.instance.deleteAddress(a['id'] as int);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      body = const Center(child: Text('No saved addresses yet.'));
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = _items[i];
          final line2 = (a['line2'] as String?)?.isNotEmpty == true ? ', ${a['line2']}' : '';
          return Card(
            child: ListTile(
              onTap: () => _openForm(a),
              title: Row(
                children: [
                  Text(a['label'] as String),
                  if (a['is_default'] == true) ...[
                    const SizedBox(width: 8),
                    const Chip(label: Text('Default'), visualDensity: VisualDensity.compact),
                  ],
                ],
              ),
              subtitle: Text(
                '${a['recipient_name']}\n${a['line1']}$line2\n'
                    '${a['city']}, ${a['district']} ${a['postal_code']}\n${a['phone']}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => _delete(a),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
    );
  }
}