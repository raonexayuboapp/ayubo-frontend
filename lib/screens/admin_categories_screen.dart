import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/category_tree.dart';
import 'admin_category_form_screen.dart';

typedef CategoryData = Map<String, dynamic>;

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<CategoryData> _items = [];
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

  Future<void> _delete(CategoryData c) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete category?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${c['name']}" will be removed. This cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.instance.adminDeleteCategory(c['id'] as int);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = theme.colorScheme.secondary;

    Widget body;

    if (_loading) {
      body = Center(
        child: CircularProgressIndicator(color: goldColor),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: goldColor),
                  foregroundColor: goldColor,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_items.isEmpty) {
      body = Center(
        child: Text(
          'No categories yet.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    } else {
      final rows = flattenCategories(_items);
      body = RefreshIndicator(
        onRefresh: _load,
        color: goldColor,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
          itemBuilder: (_, i) {
            final (c, depth) = rows[i];
            final inUse = (c['product_count'] as int) > 0 || (c['child_count'] as int) > 0;
            final isHidden = c['active'] != true;

            return ListTile(
              contentPadding: EdgeInsets.only(left: 16.0 + (depth * 20), right: 12),
              onTap: () => _openForm(c['id'] as int),
              leading: Icon(
                depth == 0 ? Icons.folder_outlined : Icons.subdirectory_arrow_right,
                size: 20,
                color: depth == 0
                    ? goldColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              title: Text(
                c['name'] as String,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${c['slug']} · ${c['product_count']} product(s)'
                '${(c['child_count'] as int) > 0 ? ' · ${c['child_count']} sub-categor${c['child_count'] == 1 ? 'y' : 'ies'}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHidden) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Hidden',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: inUse
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                          : theme.colorScheme.error.withValues(alpha: 0.8),
                    ),
                    tooltip: inUse ? 'In use: move products and sub-categories first' : 'Delete',
                    onPressed: inUse ? null : () => _delete(c),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: goldColor,
        icon: const Icon(Icons.add),
        label: const Text(
          'New category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}