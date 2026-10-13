import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';

class CartScreen extends StatefulWidget {
final Map<String, dynamic> user;

const CartScreen({
super.key,
required this.user,
});

@override
State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
List<Map<String, dynamic>> _items = [];
String _currency = 'EUR';
bool _loading = true;
bool _updating = false;
String? _error;

@override
void initState() {
super.initState();
_loadCart();
}

int? _readInt(dynamic value) {
if (value is int) return value;
if (value is num) return value.toInt();
if (value is String) return int.tryParse(value);
return null;
}

String _readString(dynamic value, {String fallback = ''}) {
if (value is String) return value;
return fallback;
}

String _formatQuantity(dynamic value) {
final quantity = double.tryParse(value.toString());

if (quantity == null) return value.toString();

return quantity
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'\.?0+$'), '');
}

Future<void> _loadCart({bool showLoader = true}) async {
if (showLoader) {
setState(() {
_loading = true;
_error = null;
});
}

try {
final response = await ApiService.instance.getCart();

if (!mounted) return;

final rawItems = response['items'];
final items = rawItems is List
? rawItems
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList()
    : <Map<String, dynamic>>[];

setState(() {
_items = items;
_currency = _readString(
response['currency'],
fallback: 'EUR',
);
_loading = false;
_error = null;
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
_error = 'Unable to load your cart. Please try again.';
_loading = false;
});
}
}

Future<void> _changeQuantity(
Map<String, dynamic> item,
double difference,
) async {
final itemId = _readInt(item['id']);
final currentQuantity =
double.tryParse(item['quantity'].toString());

if (itemId == null || currentQuantity == null) {
_showMessage('Unable to update this cart item.');
return;
}

final newQuantity = currentQuantity + difference;

if (newQuantity <= 0) {
await _removeItem(itemId);
return;
}

await _updateQuantity(itemId, newQuantity);
}

Future<void> _updateQuantity(
int itemId,
double quantity,
) async {
if (_updating) return;

setState(() => _updating = true);

try {
await ApiService.instance.updateCartItem(
itemId,
{'quantity': quantity},
);

if (!mounted) return;

await _loadCart(showLoader: false);
_showMessage('Cart updated.');
} on ApiException catch (e) {
if (mounted) _showMessage(e.message);
} catch (_) {
if (mounted) {
_showMessage('Unable to update the cart. Please try again.');
}
} finally {
if (mounted) {
setState(() => _updating = false);
}
}
}

Future<void> _removeItem(int itemId) async {
if (_updating) return;

setState(() => _updating = true);

try {
await ApiService.instance.removeCartItem(itemId);

if (!mounted) return;

await _loadCart(showLoader: false);
_showMessage('Item removed from your cart.');
} on ApiException catch (e) {
if (mounted) _showMessage(e.message);
} catch (_) {
if (mounted) {
_showMessage('Unable to remove the item. Please try again.');
}
} finally {
if (mounted) {
setState(() => _updating = false);
}
}
}

Future<void> _confirmRemove(int itemId) async {
final confirmed = await showDialog<bool>(
context: context,
builder: (dialogContext) => AlertDialog(
title: const Text('Remove item?'),
content: const Text(
'Do you want to remove this item from your cart?',
),
actions: [
TextButton(
onPressed: () => Navigator.pop(dialogContext, false),
child: const Text('Cancel'),
),
FilledButton(
onPressed: () => Navigator.pop(dialogContext, true),
child: const Text('Remove'),
),
],
),
);

if (confirmed == true && mounted) {
await _removeItem(itemId);
}
}

void _showMessage(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(content: Text(message)),
);
}

Widget _buildCartItem(Map<String, dynamic> item) {
final theme = Theme.of(context);
final itemId = _readInt(item['id']);
final variantId = _readInt(item['variant_id']);
final quantity = double.tryParse(
item['quantity'].toString(),
) ??
1;

return Card(
margin: EdgeInsets.zero,
child: Padding(
padding: const EdgeInsets.all(16),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 64,
height: 64,
decoration: BoxDecoration(
color: theme.colorScheme.surfaceContainerHighest,
borderRadius: BorderRadius.circular(12),
),
child: Icon(
Icons.shopping_bag_outlined,
size: 30,
color: theme.colorScheme.primary,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
variantId == null
? 'Product variant'
    : 'Product variant #$variantId',
style: theme.textTheme.titleMedium,
),
const SizedBox(height: 4),
Text(
'Item ID: ${itemId ?? 'Unknown'}',
style: theme.textTheme.bodySmall,
),
const SizedBox(height: 12),
Row(
children: [
IconButton(
tooltip: 'Decrease quantity',
onPressed: _updating || itemId == null
? null
    : () => _changeQuantity(item, -1),
icon: const Icon(Icons.remove_circle_outline),
),
Text(
_formatQuantity(item['quantity'] ?? 1),
style: theme.textTheme.titleMedium,
),
IconButton(
tooltip: 'Increase quantity',
onPressed: _updating || itemId == null
? null
    : () => _changeQuantity(item, 1),
icon: const Icon(Icons.add_circle_outline),
),
const Spacer(),
IconButton(
tooltip: 'Remove item',
onPressed: _updating || itemId == null
? null
    : () => _confirmRemove(itemId),
icon: const Icon(Icons.delete_outline),
),
],
),
],
),
),
],
),
),
);
}

Widget _buildEmptyCart() {
final theme = Theme.of(context);

return RefreshIndicator(
onRefresh: _loadCart,
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
children: [
const SizedBox(height: 100),
Icon(
Icons.shopping_cart_outlined,
size: 76,
color: theme.colorScheme.outline,
),
const SizedBox(height: 20),
Text(
'Your cart is empty',
textAlign: TextAlign.center,
style: theme.textTheme.headlineSmall,
),
const SizedBox(height: 8),
Text(
'Explore our products and add your favourites.',
textAlign: TextAlign.center,
style: theme.textTheme.bodyMedium,
),
const SizedBox(height: 20),
Center(
child: OutlinedButton.icon(
onPressed: () {
// Products is tab index 1 in the current app navigation.
Navigator.of(context).popUntil((route) => route.isFirst);
},
icon: const Icon(Icons.storefront_outlined),
label: const Text('Continue shopping'),
),
),
],
),
);
}

Widget _buildCart() {
return RefreshIndicator(
onRefresh: _loadCart,
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.all(16),
children: [
Text(
'Your items',
style: Theme.of(context).textTheme.titleLarge,
),
const SizedBox(height: 12),
..._items.map(
(item) => Padding(
padding: const EdgeInsets.only(bottom: 12),
child: _buildCartItem(item),
),
),
const SizedBox(height: 8),
Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Order summary',
style: Theme.of(context).textTheme.titleLarge,
),
const SizedBox(height: 12),
Row(
children: [
const Expanded(child: Text('Items')),
Text('${_items.length}'),
],
),
const SizedBox(height: 8),
Row(
children: [
const Expanded(child: Text('Currency')),
Text(_currency),
],
),
const Divider(height: 24),
Text(
'Prices and the total will be shown when product pricing '
'is available from the backend.',
style: Theme.of(context).textTheme.bodySmall,
),
],
),
),
),
if (_updating) ...[
const SizedBox(height: 16),
const Center(child: CircularProgressIndicator()),
],
],
),
);
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
const Icon(Icons.error_outline, size: 44),
const SizedBox(height: 12),
Text(
_error!,
textAlign: TextAlign.center,
),
const SizedBox(height: 12),
FilledButton.icon(
onPressed: _loadCart,
icon: const Icon(Icons.refresh),
label: const Text('Retry'),
),
],
),
),
);
} else if (_items.isEmpty) {
body = _buildEmptyCart();
} else {
body = _buildCart();
}

return Scaffold(
appBar: AppTopBar(user: widget.user),
body: body,
bottomNavigationBar: AppBottomBar(
currentIndex: 1,
user: widget.user,
),
);
}
}