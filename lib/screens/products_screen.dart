import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/product_image.dart';
import '../widgets/favourite_button.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
final Map<String, dynamic> user;
final String initialSearch;

const ProductsScreen({
super.key,
required this.user,
this.initialSearch = '',
});

@override
State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
static const _sorts = {
'newest': 'Newest',
'name': 'Name A to Z',
'price_asc': 'Price: low to high',
'price_desc': 'Price: high to low',
};

final _scroll = ScrollController();

List<Map<String, dynamic>> _categories = [];
List<Map<String, dynamic>> _products = [];

late String _searchQuery;

int? _categoryId;
String _sort = 'newest';
int _page = 1;
int _total = 0;

bool _loading = true;
bool _loadingMore = false;
String? _error;

int _requestId = 0;

@override
void initState() {
super.initState();

_searchQuery = widget.initialSearch.trim();

_scroll.addListener(_onScroll);
_loadCategories();
_load();
}

@override
void dispose() {
_scroll.dispose();
super.dispose();
}

Future<void> _loadCategories() async {
try {
final tree = await ApiService.instance.listCategories();

if (mounted) {
setState(() => _categories = tree);
}
} on ApiException {
// Categories are optional.
}
}

Future<void> _applySearch(String query) async {
if (!mounted) return;

setState(() {
_searchQuery = query.trim();
});

await _load();
}

Future<void> _load({bool reset = true}) async {
final request = ++_requestId;

setState(() {
if (reset) {
_page = 1;
_loading = true;
_loadingMore = false;
_error = null;
} else {
_loadingMore = true;
}
});

try {
final data = await ApiService.instance.listProducts(
search: _searchQuery,
categoryId: _categoryId,
sort: _sort,
page: _page,
);

if (!mounted || request != _requestId) return;

final products = (data['products'] as List<dynamic>)
    .cast<Map<String, dynamic>>();

final meta = data['meta'] as Map<String, dynamic>;

setState(() {
_products = reset
? products
    : [..._products, ...products];

_total = (meta['total'] as num).toInt();
_loading = false;
_loadingMore = false;
});
} on ApiException catch (e) {
if (!mounted || request != _requestId) return;

setState(() {
_loading = false;
_loadingMore = false;

if (reset) {
_error = e.message;
} else {
_page--;
}
});

if (!reset) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(e.message)),
);
}
} catch (_) {
if (!mounted || request != _requestId) return;

setState(() {
_loading = false;
_loadingMore = false;

if (reset) {
_error = 'Unable to load products. Please try again.';
} else {
_page--;
}
});
}
}

void _onScroll() {
if (!_scroll.hasClients) return;

final nearEnd = _scroll.position.pixels >=
_scroll.position.maxScrollExtent - 300;

if (nearEnd &&
!_loading &&
!_loadingMore &&
_products.length < _total) {
_page++;
_load(reset: false);
}
}

Future<void> _openDetail(Map<String, dynamic> product) async {
final favourite = await Navigator.push<bool>(
context,
MaterialPageRoute(
builder: (_) => ProductDetailScreen(
productId: product['id'] as int,
title: product['name'] as String,
),
),
);

if (favourite != null && mounted) {
setState(() {
product['is_favourite'] = favourite;
});
}
}

Widget _card(Map<String, dynamic> product) {
final theme = Theme.of(context);
final price = product['price_cents'] as int?;
final inStock = product['in_stock'] == true;

return Card(
clipBehavior: Clip.antiAlias,
child: InkWell(
onTap: () => _openDetail(product),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Stack(
fit: StackFit.expand,
children: [
ProductImage(
url: product['image_url'] as String?,
),
Positioned(
top: 4,
right: 4,
child: FavouriteButton(
productId: product['id'] as int,
isFavourite:
product['is_favourite'] == true,
overlay: true,
onChanged: (value) {
if (!mounted) return;

setState(() {
product['is_favourite'] = value;
});
},
),
),
],
),
),
Padding(
padding: const EdgeInsets.all(10),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
product['name'] as String,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: theme.textTheme.titleSmall,
),
const SizedBox(height: 4),
if (price != null)
Text(
formatCents(price),
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
if (!inStock)
Text(
'Out of stock',
style: TextStyle(
fontSize: 12,
color: theme.colorScheme.error,
),
),
],
),
),
],
),
),
);
}

Widget _content() {
if (_loading) {
return const Center(
child: CircularProgressIndicator(),
);
}

if (_error != null) {
return Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text(_error!),
TextButton(
onPressed: () => _load(),
child: const Text('Retry'),
),
],
),
);
}

if (_products.isEmpty) {
return RefreshIndicator(
onRefresh: () => _load(),
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
children: const [
SizedBox(height: 200),
Center(
child: Text('No products found.'),
),
],
),
);
}

return RefreshIndicator(
onRefresh: () => _load(),
child: GridView.builder(
controller: _scroll,
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.all(12),
gridDelegate:
const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 2,
childAspectRatio: 0.72,
crossAxisSpacing: 12,
mainAxisSpacing: 12,
),
itemCount: _products.length,
itemBuilder: (_, index) => _card(_products[index]),
),
);
}

Widget _buildSortControl() {
return Padding(
padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
child: Row(
children: [
const Text('Sort by'),
const SizedBox(width: 8),
PopupMenuButton<String>(
initialValue: _sort,
onSelected: (value) {
setState(() => _sort = value);
_load();
},
itemBuilder: (_) => _sorts.entries
    .map(
(entry) => PopupMenuItem<String>(
value: entry.key,
child: Text(entry.value),
),
)
    .toList(),
child: Chip(
avatar: const Icon(Icons.sort, size: 18),
label: Text(_sorts[_sort] ?? 'Newest'),
),
),
],
),
);
}

Widget _buildCategoryFilters() {
if (_categories.isEmpty) {
return const SizedBox.shrink();
}

return SizedBox(
height: 52,
child: ListView(
scrollDirection: Axis.horizontal,
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 8,
),
children: [
Padding(
padding: const EdgeInsets.only(right: 8),
child: ChoiceChip(
label: const Text('All'),
selected: _categoryId == null,
onSelected: (_) {
setState(() => _categoryId = null);
_load();
},
),
),
for (final category in _categories)
Padding(
padding: const EdgeInsets.only(right: 8),
child: ChoiceChip(
label: Text(category['name'] as String),
selected: _categoryId == category['id'],
onSelected: (_) {
setState(() {
_categoryId = category['id'] as int;
});
_load();
},
),
),
],
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppTopBar(
user: widget.user,
initialSearch: _searchQuery,
onSearchSubmitted: _applySearch,
),
body: Column(
children: [
_buildSortControl(),
_buildCategoryFilters(),
Expanded(child: _content()),
if (_loadingMore)
const LinearProgressIndicator(),
],
),
bottomNavigationBar: AppBottomBar(
currentIndex: 1,
user: widget.user,
),
);
}
}