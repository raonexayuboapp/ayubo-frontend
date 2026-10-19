import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CartScreen({super.key, required this.user});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  /// Problems that no quantity change can fix: the customer can only remove the line.
  static const _removeOnly = {'unavailable', 'unsupported', 'currency'};

  Map<String, dynamic>? _cart;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {}; // line ids with a request in flight

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
      final cart = await ApiService.instance.getCart();
      if (!mounted) return;
      setState(() {
        _cart = cart;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_cart == null) _error = e.message;
      });
      if (_cart != null) _snack(e.message); // keep showing the cart we already have
    }
  }

  Future<void> _change(Map<String, dynamic> item, int quantity) async {
    final id = item['id'] as int;
    if (_busy.contains(id)) return; // ignore a second tap while the first is still being sent

    setState(() => _busy.add(id));
    try {
      final cart = await ApiService.instance.setCartQuantity(id, quantity);
      if (!mounted) return;
      setState(() => _cart = cart);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
      _load(); // the server's numbers may have moved (for example the stock)
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    if (_busy.contains(id)) return;

    setState(() => _busy.add(id));
    try {
      final cart = await ApiService.instance.removeCartItem(id);
      if (!mounted) return;
      setState(() => _cart = cart);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('"${item['name']}" removed.'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _undo(item)),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
      _load();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _undo(Map<String, dynamic> item) async {
    try {
      final cart = await ApiService.instance.addToCart(item['variant_id'] as int, item['quantity'] as int);
      if (mounted) setState(() => _cart = cart);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message); // for example: it sold out in the meantime
    }
  }

  Widget _line(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final id = item['id'] as int;
    final busy = _busy.contains(id);
    final issue = item['issue'] as String?;
    final type = item['type'] as String;
    final pack = item['pack'] as String?;
    final removeOnly = _removeOnly.contains(issue);
    final canStep = type != 'membership' && !removeOnly;

    return Card(
      key: ValueKey(id),
      child: Opacity(
        opacity: removeOnly ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 72,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImage(url: item['image_url'] as String?),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name'] as String,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                Text(
                  [if (pack != null && pack.isNotEmpty) pack, '${formatCents(item['unit_price_cents'] as int)} each']
                      .join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                if (issue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (item['issue_message'] as String?) ?? 'This item has a problem.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(children: [
                  if (canStep)
                    QuantityStepper(
                      value: item['quantity'] as int,
                      max: item['max_quantity'] as int,
                      enabled: !busy,
                      onChanged: (q) => _change(item, q),
                    )
                  else if (type == 'membership')
                    const Chip(label: Text('Membership'), visualDensity: VisualDensity.compact),
                  const Spacer(),
                  // A line with a problem is not part of the total, so it shows no amount.
                  if (issue == null)
                    Text(formatCents(item['line_total_cents'] as int),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: busy ? null : () => _remove(item),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _footer(Map<String, dynamic> cart) {
    final theme = Theme.of(context);
    final totals = cart['totals'] as Map<String, dynamic>;
    final tax = (totals['tax'] as List<dynamic>).cast<Map<String, dynamic>>();
    final blocking = (cart['blocking_issues'] as num).toInt();
    final canCheckout = cart['can_checkout'] == true;

    Widget row(String label, String value, {TextStyle? style}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            row('Total', formatCents(totals['subtotal_cents'] as int),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            for (final t in tax)
              row('incl. ${formatPercent(t['rate_percent'] as num)}% VAT', formatCents(t['tax_cents'] as int),
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              blocking > 0
                  ? 'Items marked in red are not included. Fix or remove them to continue.'
                  : 'Shipping and discounts are added at checkout.',
              style: theme.textTheme.bodySmall?.copyWith(color: blocking > 0 ? theme.colorScheme.error : null),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canCheckout ? () => _snack('Checkout arrives with the next update.') : null,
              child: const Text('Checkout'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _empty() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        const SizedBox(height: 120),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shopping_cart_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Your cart is empty.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => AppBottomBar.open(context, 1, widget.user),
              child: const Text('Browse products'),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _cart == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _cart == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else {
      final cart = _cart!;
      final items = (cart['items'] as List<dynamic>).cast<Map<String, dynamic>>();

      body = items.isEmpty
          ? _empty()
          : Column(children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _line(items[i]),
            ),
          ),
        ),
        _footer(cart),
      ]);
    }

    return Scaffold(
      appBar: AppTopBar(user: widget.user),
      body: body,
      bottomNavigationBar: AppBottomBar(currentIndex: 3, user: widget.user),
    );
  }
}