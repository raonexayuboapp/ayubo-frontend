import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import 'admin_product_form_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  static const _statuses = ['', 'draft', 'published', 'archived'];

  final _search = TextEditingController();
  List<Map<String, dynamic>> _products = [];
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
      final list = (data['products'] as List<dynamic>).cast<Map<String, dynamic>>();
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
      MaterialPageRoute(builder: (_) => AdminProductFormScreen(productId: productId)),
    );
    if (saved == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading && _products.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _products.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else if (_products.isEmpty) {
      body = const Center(child: Text('No products found.'));
    } else {
      final hasMore = _products.length < _total;
      body = ListView.builder(
        itemCount: _products.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _products.length) {
            return TextButton(
              onPressed: _loading
                  ? null
                  : () {
                _page++;
                _load(reset: false);
              },
              child: const Text('Load more'),
            );
          }
          final p = _products[i];
          final price = p['price_cents'] as int?;
          return ListTile(
            onTap: () => _openForm(p['id'] as int),
            title: Text(p['name'] as String),
            subtitle: Text('${p['slug']} · ${price == null ? 'no active variant' : formatCents(price)}'
                ' · ${p['variant_count']} variant(s)'),
            trailing: Chip(label: Text(p['status'] as String), visualDensity: VisualDensity.compact),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Products ($_total)')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(reset: true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, slug or SKU',
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final s in _statuses)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.isEmpty ? 'All' : s),
                    selected: _status == s,
                    onSelected: (_) {
                      setState(() => _status = s);
                      _load(reset: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
    );
  }
}