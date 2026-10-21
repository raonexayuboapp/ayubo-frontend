import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/countries.dart';
import 'address_form_screen.dart';

class AddressesScreen extends StatefulWidget {
  final String defaultRecipient; // prefilled in the form for a new address
  const AddressesScreen({super.key, this.defaultRecipient = ''});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  static const _maxAddresses = 10; // the server enforces the same limit
  static const _titles = {'shipping': 'Shipping addresses', 'billing': 'Billing addresses'};

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
        _loading = false;
        if (_items.isEmpty) _error = e.message;
      });
      if (_items.isNotEmpty) _snack(e.message);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? address]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(address: address, defaultRecipient: widget.defaultRecipient),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final id = a['id'] as int;
    if (_busy.contains(id)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove the address for "${a['recipient']}" in ${a['city']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy.add(id));
    try {
      await ApiService.instance.deleteAddress(id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  String _block(Map<String, dynamic> a) {
    String? text(String key) {
      final v = a[key] as String?;
      return v == null || v.trim().isEmpty ? null : v.trim();
    }

    return [
      a['recipient'] as String,
      text('company'),
      a['street'] as String,
      text('address_line2'),
      '${a['postal_code']} ${a['city']}',
      text('region'),
      countryName(a['country_code'] as String),
    ].whereType<String>().join('\n');
  }

  Widget _card(Map<String, dynamic> a) {
    final id = a['id'] as int;

    return Card(
      key: ValueKey(id),
      child: ListTile(
        onTap: () => _openForm(a),
        title: a['is_default'] == true
            ? const Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text('Default'), visualDensity: VisualDensity.compact),
        )
            : null,
        subtitle: Text(_block(a)),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: _busy.contains(id) ? null : () => _delete(a),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    if (_items.isEmpty) {
      // A scrollable, so pull-to-refresh still works on an empty list.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 160),
          Center(child: Text('No saved addresses yet.\nAdd one to check out faster.', textAlign: TextAlign.center)),
        ]),
      );
    }

    final children = <Widget>[];
    for (final type in _titles.keys) {
      final group = _items.where((a) => a['address_type'] == type).toList();
      if (group.isEmpty) continue;

      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(_titles[type]!, style: Theme.of(context).textTheme.titleSmall),
      ));
      children.addAll(group.map(_card));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = _items.length >= _maxAddresses;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: _body(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: full ? null : () => _openForm(),
        tooltip: full ? 'You can save up to $_maxAddresses addresses' : null,
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
    );
  }
}