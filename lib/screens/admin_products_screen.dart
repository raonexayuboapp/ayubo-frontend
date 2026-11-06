import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import 'admin_product_form_screen.dart';

typedef ProductListData = Map<String, dynamic>;

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  static const _statuses = ['', 'draft', 'published', 'archived'];

  final _search = TextEditingController();
  List<ProductListData> _products = [];
  String _status = '';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.adminListProducts(
        search: _search.text.trim(),
        status: _status,
        page: _page,
      );
      final list = (data['products'] as List<dynamic>).cast<ProductListData>();
      if (!mounted) return;
      setState(() {
        _products = reset ? list : [..._products, ...list];
        _total = (data['meta'] as Map<String, dynamic>)['total'] as int;
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

  Future<void> _openForm([int? productId]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProductFormScreen(productId: productId),
      ),
    );
    if (saved == true) _load(reset: true);
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Color textColor;
    Color bgColor;

    switch (status) {
      case 'published':
        textColor = goldColor;
        bgColor = goldColor.withValues(alpha: 0.12);
        break;
      case 'archived':
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
        bgColor = theme.colorScheme.onSurface.withValues(alpha: 0.05);
        break;
      default: // draft
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
        bgColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? 'draft' : status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Widget body;
    if (_loading && _products.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    } else if (_error != null && _products.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    } else if (_products.isEmpty) {
      body = Center(
        child: Text(
          'No products found.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    } else {
      final hasMore = _products.length < _total;
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _products.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
        itemBuilder: (_, i) {
          if (i == _products.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? CircularProgressIndicator(color: goldColor, strokeWidth: 2)
                    : TextButton(
                        onPressed: () {
                          _page++;
                          _load(reset: false);
                        },
                        child: Text(
                          'Load more',
                          style: TextStyle(color: goldColor, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            );
          }
          final p = _products[i];
          final price = p['price_cents'] as int?;
          final status = p['status'] as String? ?? 'draft';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            onTap: () {
              if (p['product_type'] == 'membership') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Memberships are managed under Admin, Membership plans.'),
                  ),
                );
                return;
              }
              _openForm(p['id'] as int);
            },
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
            title: Text(
              p['name'] as String,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                '${price == null ? 'No active variant' : formatCents(price)} · ${p['variant_count']} variant(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            trailing: _buildStatusBadge(context, status),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Products ($_total)'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                hintText: 'Search products, SKU...',
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final s in _statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.isEmpty ? 'All' : s),
                      selected: _status == s,
                      showCheckmark: false,
                      side: BorderSide(
                        color: _status == s
                            ? goldColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      ),
                      selectedColor: goldColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: _status == s
                            ? goldColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: _status == s ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _status = s);
                        _load(reset: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: goldColor,
        elevation: 2,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'New product',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}