import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/favourite_button.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.listFavourites(page: _page);
      final list = (data['products'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _items = reset ? list : [..._items, ...list];
        _total = (data['meta'] as Map<String, dynamic>)['total'] as int;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (reset) {
          _error = e.message;
        } else {
          _page--; // let "Load more" try the same page again
        }
      });
      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openDetail(Map<String, dynamic> p) async {
    final favourite = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: p['id'] as int, title: p['name'] as String),
      ),
    );
    if (favourite != null && mounted) setState(() => p['is_favourite'] = favourite);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else if (_items.isEmpty) {
      // A scrollable, so pull-to-refresh still works on an empty list.
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(children: const [
          SizedBox(height: 160),
          Center(child: Text('No favourites yet.\nTap the heart on a product to save it here.', textAlign: TextAlign.center)),
        ]),
      );
    } else {
      final hasMore = _items.length < _total;
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          itemCount: _items.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _items.length) {
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

            final p = _items[i];
            final price = p['price_cents'] as int?;

            return ListTile(
              key: ValueKey(p['id']),
              onTap: () => _openDetail(p),
              leading: SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ProductImage(url: p['image_url'] as String?),
                ),
              ),
              title: Text(p['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                if (price != null) formatCents(price),
                if (p['in_stock'] != true) 'Out of stock',
              ].join(' · ')),
              // An un-favourited item stays until you refresh, so a mis-tap can be undone.
              trailing: FavouriteButton(
                productId: p['id'] as int,
                isFavourite: p['is_favourite'] == true,
                onChanged: (v) => p['is_favourite'] = v,
              ),
            );
          },
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: Text('My favourites ($_total)')), body: body);
  }
}