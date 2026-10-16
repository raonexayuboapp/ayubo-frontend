import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/category_tree.dart';
import 'admin_category_form_screen.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
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
      final items = await ApiService.instance.adminCategories();
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

  Future<void> _openForm([int? id]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminCategoryFormScreen(categoryId: id)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('"${c['name']}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.instance.adminDeleteCategory(c['id'] as int);
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else if (_items.isEmpty) {
      body = const Center(child: Text('No categories yet.'));
    } else {
      final rows = flattenCategories(_items);
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final (c, depth) = rows[i];
            final inUse = (c['product_count'] as int) > 0 || (c['child_count'] as int) > 0;

            return ListTile(
              contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 8),
              onTap: () => _openForm(c['id'] as int),
              title: Text(c['name'] as String),
              subtitle: Text('${c['slug']} · ${c['product_count']} product(s)'
                  '${(c['child_count'] as int) > 0 ? ' · ${c['child_count']} sub-categor${c['child_count'] == 1 ? 'y' : 'ies'}' : ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (c['active'] != true)
                  const Chip(label: Text('Hidden'), visualDensity: VisualDensity.compact),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: inUse ? 'In use: move its products and sub-categories first' : 'Delete',
                  onPressed: inUse ? null : () => _delete(c),
                ),
              ]),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
    );
  }
}