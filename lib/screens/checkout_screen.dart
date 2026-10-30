import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../utils/address_text.dart';
import '../utils/countries.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';
import '../widgets/product_image.dart';
import 'address_form_screen.dart';
import 'order_placed_screen.dart';

/// German law requires this button to say that the order obliges the customer to pay. When online payment goes
/// live, change it (for example "Order with obligation to pay").
const _placeOrderLabel = 'Place order';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CheckoutScreen({super.key, required this.user});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ONE key for this whole checkout attempt. A repeated request (dropped connection, double tap) returns the order
  // the server already made instead of creating a second one.
  final String _checkoutKey = newRequestKey(32);

  Map<String, dynamic>? _cart;
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _quote; // the delivery options
  Map<String, dynamic>? _preview; // the price, both ways

  int? _shippingAddressId;
  int? _methodId;
  int? _billingAddressId; // null = automatic (the delivery address, or the default billing address)
  bool _useMembership = false;
  bool _accepted = false;

  bool _loading = true;
  bool _refreshing = false;
  bool _placing = false;
  String? _loadError;
  String? _formError;
  Map<String, String> _serverErrors = {};
  int _refreshRequest = 0; // an answer that belongs to an older choice is ignored

  // ---------- derived values ----------

  String get _fullName => '${widget.user['first_name'] ?? ''} ${widget.user['last_name'] ?? ''}'.trim();

  List<Map<String, dynamic>> get _items =>
      ((_cart?['items'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _options =>
      ((_quote?['options'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();

  String? get _quoteStatus => _quote?['status'] as String?;
  bool get _requiresShipping => _quote?['requires_shipping'] == true;

  Map<String, dynamic>? get _membership => _preview?['membership'] as Map<String, dynamic>?;

  /// The price of the way the customer chose to pay.
  /// The price of the way the customer chose to pay.
  Map<String, dynamic>? get _chosen {
    final preview = _preview;
    if (preview == null) return null;

    if (_useMembership) {
      final membership = preview['membership'] as Map<String, dynamic>?;
      return membership?['pricing'] as Map<String, dynamic>?;
    }

    return preview['standalone'] as Map<String, dynamic>?;
  }

  int _cents(String key) => (_chosen?[key] as num?)?.toInt() ?? 0;
  int get _total => _cents('total_cents'); // what the order costs
  int get _discount => _cents('discount_cents');
  int get _credit => _cents('credit_cents'); // paid from the membership
  int get _toPay => _cents('pay_cents'); // left to pay another way
  int get _goods => (_preview?['goods_cents'] as num?)?.toInt() ?? 0;
  int get _shipping => (_preview?['shipping_cents'] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> _ofType(String type) => _addresses.where((a) => a['address_type'] == type).toList();

  /// The first thing that stops the customer from ordering, or null when everything is in place.
  String? get _blocker {
    final cart = _cart;
    if (cart == null) return 'Loading…';
    if (cart['can_checkout'] != true) return 'Fix the items marked in red in your cart first.';
    if (_quote == null || _preview == null) return 'Calculating…';
    if (_requiresShipping) {
      if (_shippingAddressId == null) return 'Choose a delivery address.';
      if (_quoteStatus == 'country_not_served') return 'We do not deliver to that address.';
      if (_quoteStatus == 'no_option') return 'No delivery price is set for this order.';
      if (_quoteStatus != 'ok' || _methodId == null) return 'Choose a delivery method.';
    }
    if (_useMembership && _chosen == null) return 'Your membership cannot be used for this order.';
    if (!_accepted) return 'Accept the terms to place your order.';
    return null;
  }

  bool get _canPlace => _blocker == null && !_placing && !_refreshing;

  // ---------- loading ----------

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    setState(() {
      _loading = _cart == null;
      _loadError = null;
    });
    try {
      final api = ApiService.instance;
      final results = await Future.wait<Object>([api.getCart(), api.listAddresses()]);
      if (!mounted) return;

      setState(() {
        _cart = results[0] as Map<String, dynamic>;
        _addresses = results[1] as List<Map<String, dynamic>>;
        _loading = false;
        _repairSelections();
      });
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_cart == null) _loadError = e.message;
      });
      if (_cart != null) _snack(e.message);
    }
  }

  /// Keeps the chosen addresses valid after the list changed.
  void _repairSelections() {
    final shipping = _ofType('shipping');
    if (!shipping.any((a) => a['id'] == _shippingAddressId)) {
      final defaults = shipping.where((a) => a['is_default'] == true);
      _shippingAddressId = defaults.isNotEmpty
          ? defaults.first['id'] as int
          : (shipping.isEmpty ? null : shipping.first['id'] as int);
    }
    if (_billingAddressId != null && !_ofType('billing').any((a) => a['id'] == _billingAddressId)) {
      _billingAddressId = null;
    }
  }

  /// Asks the server for the delivery options and the price. With [quote] false only the price is refreshed
  /// (the customer picked another delivery method).
  Future<void> _refresh({bool quote = true}) async {
    final request = ++_refreshRequest;
    setState(() => _refreshing = true);

    try {
      final api = ApiService.instance;
      final fresh = quote ? await api.shippingQuote(addressId: _shippingAddressId) : _quote!;
      if (!mounted || request != _refreshRequest) return;

      final options = ((fresh['options'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
      var method = _methodId;
      if (!options.any((o) => o['method_id'] == method)) {
        method = options.isEmpty ? null : options.first['method_id'] as int; // the cheapest comes first
      }

      final preview = await api.checkoutPreview(addressId: _shippingAddressId, methodId: method);
      if (!mounted || request != _refreshRequest) return;

      setState(() {
        _quote = fresh;
        _methodId = method;
        _preview = preview;
        _refreshing = false;
        if (_useMembership && (preview['membership'] as Map<String, dynamic>)['available'] != true) {
          _useMembership = false; // it stopped being possible (for example the credit ran out)
        }
      });
    } on ApiException catch (e) {
      if (!mounted || request != _refreshRequest) return;
      setState(() {
        _refreshing = false;
        _formError = e.message;
      });
    }
  }

  Future<void> _addAddress(String type) async {
    final known = _addresses.map((a) => a['id']).toSet();

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddressFormScreen(initialType: type, defaultRecipient: _fullName)),
    );
    if (saved != true || !mounted) return;

    try {
      final fresh = await ApiService.instance.listAddresses();
      if (!mounted) return;

      setState(() {
        _addresses = fresh;
        final created = fresh.where((a) => !known.contains(a['id'])).toList();
        if (created.isNotEmpty) {
          final a = created.first; // the new address is selected for the role it was saved with
          if (a['address_type'] == 'shipping') {
            _shippingAddressId = a['id'] as int;
          } else {
            _billingAddressId = a['id'] as int;
          }
        }
        _repairSelections();
      });
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  // ---------- placing the order ----------

  Future<void> _place() async {
    if (!_canPlace) return;

    setState(() {
      _placing = true;
      _formError = null;
      _serverErrors = {};
    });

    final body = <String, dynamic>{
      'checkout_key': _checkoutKey,
      'expected_total_cents': _total, // the total the customer is looking at
      'accept_terms': true,
      'pay_with_membership': _useMembership,
      if (_requiresShipping) 'shipping_address_id': _shippingAddressId,
      if (_requiresShipping) 'shipping_method_id': _methodId,
      if (_billingAddressId != null) 'billing_address_id': _billingAddressId,
    };

    try {
      final data = await ApiService.instance.placeOrder(body);
      if (!mounted) return;

      CartState.instance.refresh(); // the cart became the order: the badge goes back to zero
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderPlacedScreen(order: data['order'] as Map<String, dynamic>, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      final errs = e.fieldErrors;
      final changed = errs['total_cents'];

      if (changed != null) {
        // A price changed since the customer last saw it. Nothing was created. Show the new total and ask again.
        setState(() => _placing = false);
        await _load();
        if (mounted) {
          _snack('The total changed to ${formatCents(int.tryParse(changed) ?? _total)}. '
              'Please review your order and place it again.');
        }
        return;
      }

      setState(() {
        _serverErrors = errs;
        _formError = errs['cart'] ?? (errs.isEmpty ? e.message : null);
        _placing = false;
      });
      if (errs.containsKey('cart') || errs.containsKey('pay_with_membership')) _load();
    }
  }

  // ---------- pieces of the screen ----------

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );

  /// A card that works like a radio button: the selected one has a thick outline. A null [onTap] disables it.
  Widget _choice({
    Key? key,
    required bool selected,
    required VoidCallback? onTap,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: key,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? scheme.primary : null),
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  List<Widget> _itemRows() {
    final theme = Theme.of(context);

    return [
      for (final item in _items)
        ListTile(
          key: ValueKey(item['id']),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ProductImage(url: item['image_url'] as String?)),
          ),
          title: Text(item['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text([
            if ((item['pack'] as String?)?.isNotEmpty == true) item['pack'] as String,
            '${item['quantity']} × ${formatCents(item['unit_price_cents'] as int)}',
          ].join(' · ')),
          trailing: item['issue'] == null
              ? Text(formatCents(item['line_total_cents'] as int), style: theme.textTheme.titleSmall)
              : Text('Problem', style: TextStyle(color: theme.colorScheme.error)),
        ),
    ];
  }

  String? _hint(Map<String, dynamic> option) {
    final next = option['next_band'] as Map<String, dynamic>?;
    if (next == null) return null;

    final remaining = formatCents(next['remaining_cents'] as int);
    return next['price_cents'] == 0
        ? 'Spend $remaining more for free shipping.'
        : 'Spend $remaining more and shipping drops to ${formatCents(next['price_cents'] as int)}.';
  }

  List<Widget> _methodChoices() {
    final status = _quoteStatus;
    final country = _quote?['country_code'] as String?;
    final theme = Theme.of(context);

    if (status == 'ok') {
      return [
        for (final o in _options)
          _choice(
            key: ValueKey('m${o['method_id']}'),
            selected: _methodId == o['method_id'],
            onTap: _placing
                ? null
                : () {
              setState(() => _methodId = o['method_id'] as int);
              _refresh(quote: false); // only the price changes
            },
            title: Text(o['name'] as String),
            subtitle: _hint(o) == null ? null : Text(_hint(o)!),
            trailing: Text(o['free'] == true ? 'Free' : formatCents(o['price_cents'] as int),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
      ];
    }
    if (status == 'needs_address') return [const Text('Choose or add a delivery address to see the delivery methods.')];
    if (status == 'country_not_served') {
      return [_errorText('We do not deliver to ${country == null ? 'that country' : countryName(country)} yet.')];
    }
    if (status == 'no_option') return [_errorText('No delivery price is set for this order. Please contact support.')];
    return const [];
  }

  List<Widget> _deliverySection() {
    final shipping = _ofType('shipping');

    return [
      _heading('Delivery address'),
      if (shipping.isEmpty) const Text('Add the address we should deliver to.'),
      for (final a in shipping)
        _choice(
          key: ValueKey('s${a['id']}'),
          selected: _shippingAddressId == a['id'],
          onTap: _placing
              ? null
              : () {
            setState(() => _shippingAddressId = a['id'] as int);
            _refresh(); // the delivery options depend on the country
          },
          title: Text(a['recipient'] as String),
          subtitle: Text(addressOneLine(a)),
        ),
      TextButton.icon(
        onPressed: _placing ? null : () => _addAddress('shipping'),
        icon: const Icon(Icons.add),
        label: const Text('Add delivery address'),
      ),
      if (_serverErrors['shipping_address_id'] != null) _errorText(_serverErrors['shipping_address_id']!),
      _heading('Delivery method'),
      if (_refreshing) const LinearProgressIndicator(),
      ..._methodChoices(),
      if (_serverErrors['shipping_method_id'] != null) _errorText(_serverErrors['shipping_method_id']!),
    ];
  }

  List<Widget> _billingSection() {
    final billing = _ofType('billing');

    return [
      _heading('Billing address'),
      _choice(
        selected: _billingAddressId == null,
        onTap: _placing ? null : () => setState(() => _billingAddressId = null),
        title: Text(_requiresShipping ? 'Same as the delivery address' : 'My default billing address (if I have one)'),
      ),
      for (final a in billing)
        _choice(
          key: ValueKey('b${a['id']}'),
          selected: _billingAddressId == a['id'],
          onTap: _placing ? null : () => setState(() => _billingAddressId = a['id'] as int),
          title: Text(a['recipient'] as String),
          subtitle: Text(addressOneLine(a)),
        ),
      TextButton.icon(
        onPressed: _placing ? null : () => _addAddress('billing'),
        icon: const Icon(Icons.add),
        label: const Text('Add billing address'),
      ),
      if (_serverErrors['billing_address_id'] != null) _errorText(_serverErrors['billing_address_id']!),
    ];
  }

  /// "Pay normally" or "Pay with my membership". Only members see it.
  List<Widget> _paymentSection() {
    final m = _membership;
    final preview = _preview;
    if (m == null || preview == null || m['discount_percent'] == null) return const []; // not a member

    final standalone = preview['standalone'] as Map<String, dynamic>;
    final available = m['available'] == true;
    final pricing = m['pricing'] as Map<String, dynamic>?;
    final balance = (m['balance_cents'] as num).toInt();
    final percent = m['discount_percent'] as num;

    String line() {
      if (!available || pricing == null) return (m['reason'] as String?) ?? 'Not available for this order.';

      final credit = (pricing['credit_cents'] as num).toInt();
      final pay = (pricing['pay_cents'] as num).toInt();
      final total = formatCents((pricing['total_cents'] as num).toInt());
      final left = formatCents(balance - credit);

      return pay == 0
          ? 'Total $total, all from your credit. Credit left: $left.'
          : '${formatCents(credit)} from your credit, ${formatCents(pay)} to pay another way. Credit left: $left.';
    }

    return [
      _heading('How do you want to pay?'),
      _choice(
        selected: !_useMembership,
        onTap: _placing ? null : () => setState(() => _useMembership = false),
        title: const Text('Pay normally'),
        subtitle: Text('Total ${formatCents((standalone['total_cents'] as num).toInt())}'),
      ),
      _choice(
        selected: _useMembership,
        onTap: _placing || !available ? null : () => setState(() => _useMembership = true),
        title: Text('Pay with my membership · ${formatPercent(percent)}% off'),
        subtitle: Text(line()),
      ),
      if (_serverErrors['pay_with_membership'] != null) _errorText(_serverErrors['pay_with_membership']!),
    ];
  }

  Widget _summary() {
    final theme = Theme.of(context);

    Widget row(String label, String value, {bool bold = false}) {
      final style = bold ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) : null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: style), Text(value, style: style)]),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          row('Items', formatCents(_goods)),
          if (_discount > 0) row('Member discount', '−${formatCents(_discount)}'),
          if (_requiresShipping) row('Shipping', _methodId == null ? '–' : (_shipping == 0 ? 'Free' : formatCents(_shipping))),
          const Divider(height: 20),
          row('Total', formatCents(_total), bold: true),
          if (_credit > 0) ...[
            const SizedBox(height: 4),
            row('From your membership credit', '−${formatCents(_credit)}'),
            row(_toPay == 0 ? 'Nothing left to pay' : 'To pay now', formatCents(_toPay), bold: _toPay > 0),
          ],
          const SizedBox(height: 4),
          Text('All prices include VAT. The VAT breakdown is shown on your order.', style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_loadError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_loadError!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Your cart is empty.'),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        ]),
      );
    }

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _heading('Your order'),
        ..._itemRows(),
        if (_cart?['can_checkout'] != true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(child: Text('Some items in your cart cannot be ordered.', style: TextStyle(color: theme.colorScheme.error))),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to cart')),
            ]),
          ),
        if (_requiresShipping) ..._deliverySection(),
        ..._billingSection(),
        ..._paymentSection(),
        _heading('Summary'),
        _summary(),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: _placing ? null : (v) => setState(() => _accepted = v ?? false),
          title: const Text('I accept the terms and conditions and the cancellation policy.'),
        ),
        if (_serverErrors['accept_terms'] != null) _errorText(_serverErrors['accept_terms']!),
        if (_formError != null) ...[
          _errorText(_formError!),
          if (_serverErrors.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('You can safely press the button again: the same order is never created twice.',
                  style: theme.textTheme.bodySmall),
            ),
        ],
      ],
    );
  }

  Widget? _bottomBar() {
    if (_loading || _cart == null || _items.isEmpty) return null;

    final blocker = _blocker;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (blocker != null && !_placing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(blocker, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              ),
            FilledButton(
              onPressed: _canPlace ? _place : null,
              child: _placing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('$_placeOrderLabel · ${formatCents(_total)}'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // While the order is being sent, leaving would hide whether it worked.
    return PopScope(
      canPop: !_placing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: _body(),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }
}