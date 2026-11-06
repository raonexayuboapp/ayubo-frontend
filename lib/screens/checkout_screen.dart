import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../utils/address_text.dart';
import '../utils/countries.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';
import '../widgets/app_header.dart';
import '../widgets/product_image.dart';
import 'address_form_screen.dart';
import 'order_placed_screen.dart';

/// German law (§ 312j Abs. 3 BGB) requires this button to say that the order obliges the customer to pay ("Zahlungspflichtig bestellen").
String _placeOrderText(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
  return isDe ? 'Zahlungspflichtig bestellen' : (l10n?.placeOrder ?? 'Place order');
}

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

  // Voucher codes the customer typed that the server confirmed: {code, suffix, balance_cents, expires_at}.
  // They live only in memory: never stored, never logged.
  final _voucherInput = TextEditingController();
  final List<Map<String, dynamic>> _vouchers = [];
  bool _checkingVoucher = false;
  String? _voucherError;

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
  Map<String, dynamic>? get _chosen {
    final p = _preview;
    if (p == null) return null;
    return _useMembership
        ? (_membership?['pricing'] as Map<String, dynamic>?)
        : (p['standalone'] as Map<String, dynamic>?);
  }

  int _cents(String key) => (_chosen?[key] as num?)?.toInt() ?? 0;
  int get _total => _cents('total_cents'); // what the order costs
  int get _discount => _cents('discount_cents');
  int get _credit => _cents('credit_cents'); // paid from the membership
  /// Vouchers pay for products only: a gift voucher or a membership in the cart switches the section off.
  bool get _vouchersAllowed => _items.every((i) => i['type'] == 'physical' || i['type'] == 'service');

  int get _voucherBalance => _vouchers.fold<int>(0, (sum, v) => sum + (v['balance_cents'] as num).toInt());

  /// What the vouchers will pay: the lesser of the order total and their balances (the server works it out exactly).
  int get _voucherApplied => _vouchers.isEmpty ? 0 : (_voucherBalance < _total ? _voucherBalance : _total);

  int get _toPay => _vouchers.isNotEmpty ? _total - _voucherApplied : _cents('pay_cents'); // left to pay another way
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

  @override
  void dispose() {
    _voucherInput.dispose();
    super.dispose();
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

  Future<void> _addVoucher() async {
    final typed = _voucherInput.text.trim();
    if (typed.isEmpty || _checkingVoucher) return;

    final code = typed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    String? problem;
    if (code.length != 16) {
      problem = 'A voucher code has 16 letters and numbers.';
    } else if (_vouchers.any((v) => v['code'] == code)) {
      problem = 'You already added this voucher.';
    } else if (_vouchers.length >= 5) {
      problem = 'You can use up to 5 vouchers per order.';
    }
    if (problem != null) {
      setState(() => _voucherError = problem);
      return;
    }

    setState(() {
      _checkingVoucher = true;
      _voucherError = null;
    });

    try {
      final result = (await ApiService.instance.checkVouchers([code])).first;
      if (!mounted) return;

      if (result['ok'] != true) {
        setState(() {
          _checkingVoucher = false;
          _voucherError = result['message'] as String?;
        });
        return;
      }

      final hadMembership = _useMembership;
      setState(() {
        _vouchers.add({
          'code': code,
          'suffix': result['suffix'],
          'balance_cents': result['balance_cents'],
          'expires_at': result['expires_at'],
        });
        _voucherInput.clear();
        _checkingVoucher = false;
        _useMembership = false; // vouchers and membership credit cannot be combined
      });
      if (hadMembership) _snack('Paying with your membership was switched off: it cannot be combined with a voucher.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingVoucher = false;
        _voucherError = e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\\n') : e.message;
      });
    }
  }

  void _removeVoucher(int index) => setState(() => _vouchers.removeAt(index));

  /// After the server refused a voucher: show what each one is now (used elsewhere, expired…).
  Future<void> _recheckVouchers() async {
    if (_vouchers.isEmpty) return;

    final codes = _vouchers.map((v) => v['code'] as String).toList();
    try {
      final results = await ApiService.instance.checkVouchers(codes);
      if (!mounted) return;

      setState(() {
        final kept = <Map<String, dynamic>>[];
        for (var i = 0; i < codes.length && i < results.length; i++) {
          if (results[i]['ok'] == true) {
            kept.add({
              'code': codes[i],
              'suffix': results[i]['suffix'],
              'balance_cents': results[i]['balance_cents'],
              'expires_at': results[i]['expires_at'],
            });
          } else {
            _voucherError = 'Voucher •••• ${results[i]['suffix']}: ${results[i]['message']}';
          }
        }
        _vouchers
          ..clear()
          ..addAll(kept);
      });
    } on ApiException {
      // The next try shows the real error.
    }
  }

  void _chooseMembership() {
    final hadVouchers = _vouchers.isNotEmpty;
    setState(() {
      _useMembership = true;
      _vouchers.clear();
      _voucherError = null;
    });
    if (hadVouchers) _snack('Vouchers cannot be combined with membership credit. Your vouchers were removed from this order.');
  }

  List<Widget> _voucherSection() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    final widgets = <Widget>[_heading(l10n?.giftVouchers ?? 'Vouchers')];

    if (!_vouchersAllowed) {
      return [
        ...widgets,
        Text(
            isDe
                ? 'Gutscheine können nur für Produkte verwendet werden. Bitte entfernen Sie Geschenkgutscheine und Mitgliedschaften aus Ihrem Warenkorb.'
                : 'Vouchers can only pay for products. Remove gift vouchers and memberships from your cart to use a voucher.',
            style: theme.textTheme.bodySmall),
      ];
    }
    if (_useMembership) {
      return [
        ...widgets,
        Text(
            isDe
                ? 'Gutscheine können nicht mit der Bezahlung über eine Mitgliedschaft kombiniert werden. Wählen Sie oben "Regulär bezahlen", um einen Gutschein einzulösen.'
                : 'Vouchers cannot be combined with paying by membership. Choose "Pay normally" above to use a voucher.',
            style: theme.textTheme.bodySmall),
      ];
    }

    for (var i = 0; i < _vouchers.length; i++) {
      final v = _vouchers[i];
      final expires = v['expires_at'] as String?;

      widgets.add(Card(
        key: ValueKey(v['code']),
        child: ListTile(
          leading: const Icon(Icons.card_giftcard_outlined),
          title: Text(isDe ? 'Gutschein •••• ${v['suffix']}' : 'Voucher •••• ${v['suffix']}'),
          subtitle: Text('${isDe ? 'Guthaben' : 'Balance'} ${formatCents((v['balance_cents'] as num).toInt())}'
              '${expires == null ? '' : (isDe ? ' · gültig bis ${expires.substring(0, 10)}' : ' · valid until ${expires.substring(0, 10)}') }'),
          trailing: IconButton(
            tooltip: l10n?.remove ?? 'Remove',
            icon: const Icon(Icons.close),
            onPressed: _placing ? null : () => _removeVoucher(i),
          ),
        ),
      ));
    }

    widgets.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: TextField(
          controller: _voucherInput,
          enabled: !_placing && !_checkingVoucher,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _addVoucher(),
          decoration: InputDecoration(
            labelText: l10n?.voucherCode ?? 'Voucher code',
            hintText: 'XXXX-XXXX-XXXX-XXXX',
          ),
        ),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FilledButton.tonal(
          onPressed: _placing || _checkingVoucher ? null : _addVoucher,
          child: _checkingVoucher
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n?.add ?? 'Add'),
        ),
      ),
    ]));

    final error = _voucherError ?? _serverErrors['voucher_codes'];
    if (error != null) widgets.add(_errorText(error));

    return widgets;
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
      if (_vouchers.isNotEmpty) 'voucher_codes': [for (final v in _vouchers) v['code']],
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
      if (errs.containsKey('voucher_codes')) {
        setState(() => _voucherError = errs['voucher_codes']);
        _recheckVouchers(); // a voucher may have changed (used elsewhere, expired): show what it is now
      }
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
    final l10n = AppLocalizations.of(context);
    final shipping = _ofType('shipping');

    return [
      _heading(l10n?.shippingAddress ?? 'Delivery address'),
      if (shipping.isEmpty) Text(l10n?.addDeliveryAddress ?? 'Add the address we should deliver to.'),
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
        label: Text(l10n?.addDeliveryAddress ?? 'Add delivery address'),
      ),
      if (_serverErrors['shipping_address_id'] != null) _errorText(_serverErrors['shipping_address_id']!),
      _heading(l10n?.shippingMethod ?? 'Delivery method'),
      if (_refreshing) const LinearProgressIndicator(),
      ..._methodChoices(),
      if (_serverErrors['shipping_method_id'] != null) _errorText(_serverErrors['shipping_method_id']!),
    ];
  }

  List<Widget> _billingSection() {
    final l10n = AppLocalizations.of(context);
    final billing = _ofType('billing');

    return [
      _heading(l10n?.billingAddress ?? 'Billing address'),
      _choice(
        selected: _billingAddressId == null,
        onTap: _placing ? null : () => setState(() => _billingAddressId = null),
        title: Text(_requiresShipping
            ? (l10n?.sameAsDeliveryAddress ?? 'Same as the delivery address')
            : (l10n?.defaultBillingAddress ?? 'My default billing address (if I have one)')),
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
        label: Text(l10n?.addBillingAddress ?? 'Add billing address'),
      ),
      if (_serverErrors['billing_address_id'] != null) _errorText(_serverErrors['billing_address_id']!),
    ];
  }

  /// "Pay normally" or "Pay with my membership". Only members see it.
  List<Widget> _paymentSection() {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
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

      if (isDe) {
        return pay == 0
            ? 'Gesamtbetrag $total, vollständig aus Ihrem Guthaben. Verbleibendes Guthaben: $left.'
            : '${formatCents(credit)} aus Ihrem Guthaben, ${formatCents(pay)} anderweitig zu zahlen. Verbleibend: $left.';
      }
      return pay == 0
          ? 'Total $total, all from your credit. Credit left: $left.'
          : '${formatCents(credit)} from your credit, ${formatCents(pay)} to pay another way. Credit left: $left.';
    }

    return [
      _heading(l10n?.paymentMethod ?? 'How do you want to pay?'),
      _choice(
        selected: !_useMembership,
        onTap: _placing ? null : () => setState(() => _useMembership = false),
        title: Text(l10n?.payNormally ?? 'Pay normally'),
        subtitle: Text('${isDe ? 'Gesamtbetrag' : 'Total'} ${formatCents((standalone['total_cents'] as num).toInt())}'),
      ),
      _choice(
        selected: _useMembership,
        onTap: _placing || !available ? null : _chooseMembership,
        title: Text('${l10n?.payWithMembership ?? 'Pay with my membership'} · ${formatPercent(percent)}% ${isDe ? 'Rabatt' : 'off'}'),
        subtitle: Text(line()),
      ),
      if (_serverErrors['pay_with_membership'] != null) _errorText(_serverErrors['pay_with_membership']!),
    ];
  }

  Widget _summary() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

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
          row(isDe ? 'Artikel' : 'Items', formatCents(_goods)),
          if (_discount > 0) row(isDe ? 'Mitgliederrabatt' : 'Member discount', '−${formatCents(_discount)}'),
          if (_requiresShipping)
            row(
              l10n?.shipping ?? 'Shipping',
              _methodId == null ? '–' : (_shipping == 0 ? (l10n?.shippingFree ?? 'Free') : formatCents(_shipping)),
            ),
          const Divider(height: 20),
          row(l10n?.total ?? 'Total', formatCents(_total), bold: true),
          if (_credit > 0) ...[
            const SizedBox(height: 4),
            row(isDe ? 'Aus Ihrem Guthaben' : 'From your membership credit', '−${formatCents(_credit)}'),
            row(_toPay == 0 ? (isDe ? 'Nichts mehr zu zahlen' : 'Nothing left to pay') : (isDe ? 'Jetzt zu zahlen' : 'To pay now'), formatCents(_toPay), bold: _toPay > 0),
          ],
          if (_voucherApplied > 0) ...[
            const SizedBox(height: 4),
            row(isDe ? 'Aus Ihren Gutscheinen' : 'From your vouchers', '−${formatCents(_voucherApplied)}'),
            row(_toPay == 0 ? (isDe ? 'Nichts mehr zu zahlen' : 'Nothing left to pay') : (isDe ? 'Jetzt zu zahlen' : 'To pay now'), formatCents(_toPay), bold: _toPay > 0),
          ],
          const SizedBox(height: 4),
          Text(
            l10n?.vatNotice ?? 'All prices include VAT. The VAT breakdown is shown on your order.',
            style: theme.textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_loadError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_loadError!),
          TextButton(onPressed: _load, child: Text(l10n?.retry ?? 'Retry')),
        ]),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n?.cartEmpty ?? 'Your cart is empty.'),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.back ?? 'Back')),
        ]),
      );
    }

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _heading(isDe ? 'Ihre Bestellung' : 'Your order'),
        ..._itemRows(),
        if (_cart?['can_checkout'] != true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  isDe
                      ? 'Einige Artikel in Ihrem Warenkorb können nicht bestellt werden.'
                      : 'Some items in your cart cannot be ordered.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isDe ? 'Zurück zum Warenkorb' : 'Back to cart'),
              ),
            ]),
          ),
        if (_requiresShipping) ..._deliverySection(),
        ..._billingSection(),
        ..._paymentSection(),
        ..._voucherSection(),
        _heading(l10n?.orderSummary ?? 'Summary'),
        _summary(),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: _placing ? null : (v) => setState(() => _accepted = v ?? false),
          title: Text(l10n?.termsAndConditions ?? 'I accept the terms and conditions and the cancellation policy.'),
        ),
        if (_serverErrors['accept_terms'] != null) _errorText(_serverErrors['accept_terms']!),
        if (_formError != null) ...[
          _errorText(_formError!),
          if (_serverErrors.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isDe
                    ? 'Sie können bedenkenlos erneut bestellen: Dieselbe Bestellung wird nie doppelt angelegt.'
                    : 'You can safely press the button again: the same order is never created twice.',
                style: theme.textTheme.bodySmall,
              ),
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
                  : Text('${_placeOrderText(context)} · ${formatCents(_total)}'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    // While the order is being sent, leaving would hide whether it worked.
    return PopScope(
      canPop: !_placing,
      child: Scaffold(
        appBar: AppHeader(
          title: l10n?.checkout ?? 'Checkout',
          subtitle: isDe ? 'Sichere Kasse' : 'Secure Checkout',
          user: widget.user,
          showBackButton: !_placing,
        ),
        body: _body(),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }
}