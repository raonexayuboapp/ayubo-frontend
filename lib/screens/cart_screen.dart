import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/shipping_estimate.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

typedef CartData = Map<String, dynamic>;

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CartScreen({super.key, required this.user});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _removeOnly = {'unavailable', 'unsupported', 'currency'};

  late Map<String, dynamic> _user = widget.user;
  CartData? _cart;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  bool get _isGuest => _user.isEmpty;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _checkAuthAndLoad() async {
    final hasTok = await ApiService.instance.hasToken();
    if (!hasTok || _isGuest) {
      if (mounted) {
        setState(() {
          _loading = false;
          _cart = null;
        });
      }
      return;
    }
    _load();
  }

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
        if (e.statusCode == 401) {
          _user = {};
          _cart = null;
          _error = null;
        } else {
          if (_cart == null) _error = e.message;
        }
      });
      if (_cart != null && e.statusCode != 401) _snack(e.message);
    }
  }

  Future<void> _change(CartData item, int quantity) async {
    final id = item['id'] as int;
    if (_busy.contains(id)) return;

    setState(() => _busy.add(id));
    try {
      final cart = await ApiService.instance.setCartQuantity(id, quantity);
      if (!mounted) return;
      setState(() => _cart = cart);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
      _load();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _remove(CartData item) async {
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
          action: SnackBarAction(
            label: 'Undo',
            textColor: Theme.of(context).colorScheme.secondary,
            onPressed: () => _undo(item),
          ),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
      _load();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _undo(CartData item) async {
    try {
      final cart = await ApiService.instance.addToCart(item['variant_id'] as int, item['quantity'] as int);
      if (mounted) setState(() => _cart = cart);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _checkout() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CheckoutScreen(user: _user)));
    if (mounted) _load();
  }

  Widget _line(CartData item) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final eachStr = l10n?.each ?? 'each';

    final id = item['id'] as int;
    final busy = _busy.contains(id);
    final issue = item['issue'] as String?;
    final type = item['type'] as String;
    final pack = item['pack'] as String?;
    final removeOnly = _removeOnly.contains(issue);
    final canStep = type != 'membership' && !removeOnly;

    return Container(
      key: ValueKey(id),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: issue != null
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Opacity(
        opacity: removeOnly ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [if (pack != null && pack.isNotEmpty) pack, '${formatCents(item['unit_price_cents'] as int)} $eachStr']
                          .join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (issue != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          (item['issue_message'] as String?) ?? 'This item has a problem.',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (canStep)
                          QuantityStepper(
                            value: item['quantity'] as int,
                            max: item['max_quantity'] as int,
                            enabled: !busy,
                            onChanged: (q) => _change(item, q),
                          )
                        else if (type == 'membership')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n?.memberships ?? 'Membership',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: goldColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (issue == null)
                          Text(
                            formatCents(item['line_total_cents'] as int),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n?.removeItem ?? 'Remove',
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: busy ? null : () => _remove(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(CartData cart) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    final totals = cart['totals'] as Map<String, dynamic>;
    final tax = (totals['tax'] as List<dynamic>).cast<CartData>();
    final blocking = (cart['blocking_issues'] as num).toInt();
    final canCheckout = cart['can_checkout'] == true;

    Widget row(String label, String value, {TextStyle? style}) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: style), Text(value, style: style)],
        );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(
                l10n?.subtotal ?? 'Subtotal',
                formatCents(totals['subtotal_cents'] as int),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final t in tax)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: row(
                    isDe
                        ? 'inkl. ${formatPercent(t['rate_percent'] as num)}% MwSt.'
                        : 'incl. ${formatPercent(t['rate_percent'] as num)}% VAT',
                    formatCents(t['tax_cents'] as int),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ShippingEstimate(cartKey: '${totals['subtotal_cents']}|${totals['item_count']}|$blocking'),
              if (blocking > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    isDe
                        ? 'Rot markierte Artikel sind nicht enthalten. Bitte korrigieren oder entfernen.'
                        : 'Items marked in red are not included. Fix or remove them to continue.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: canCheckout ? _checkout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: goldColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  l10n?.proceedToCheckout ?? 'Checkout',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      color: goldColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 48,
                    color: goldColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.cartEmpty ?? 'Your cart is empty.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => AppBottomBar.open(context, 1, _user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: goldColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n?.exploreCollection ?? 'Browse products',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestCartView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  border: Border.all(
                    color: AppTheme.brandGold.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandGold.withValues(alpha: 0.25),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 52,
                  color: AppTheme.brandGoldDark,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.myCart ?? 'Your Shopping Cart',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n?.guestCartMessage ??
                    'Sign in or create an account to view your saved cart, sync items across devices, and proceed to checkout.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  final user = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(returnUserOnSuccess: true),
                    ),
                  );
                  if (user != null && mounted) {
                    setState(() {
                      _user = user;
                    });
                    _load();
                  }
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  l10n?.loginToViewCart ?? 'Log In to View Cart',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.brandGold,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppTheme.brandGold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final user = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(returnUserOnSuccess: true),
                    ),
                  );
                  if (user != null && mounted) {
                    setState(() {
                      _user = user;
                    });
                    _load();
                  }
                },
                icon: const Icon(Icons.person_add_outlined, size: 20),
                label: Text(
                  l10n?.register ?? 'Create an Account',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppTheme.primaryGreen,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(
                    color: AppTheme.brandGold.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => AppBottomBar.open(context, 1, _user),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: Text(l10n?.exploreProducts ?? 'Browse Organic Products'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Widget body;

    if (_isGuest) {
      body = _guestCartView();
    } else if (_loading && _cart == null) {
      body = Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    } else if (_error != null && _cart == null) {
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
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    } else {
      final cart = _cart!;
      final items = (cart['items'] as List<dynamic>).cast<CartData>();

      body = items.isEmpty
          ? _empty()
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: goldColor,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _line(items[i]),
                    ),
                  ),
                ),
                _footer(cart),
              ],
            );
    }

    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;
    final cartItems = ((_cart?['items'] as List<dynamic>?) ?? const []).cast<CartData>();
    final itemCount = cartItems.length;

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.navCart ?? 'Shopping Cart',
        subtitle: itemCount > 0
            ? '$itemCount ${itemCount == 1 ? (isDe ? 'Artikel' : 'item') : (isDe ? 'Artikel' : 'items')}'
            : null,
        user: _user,
        showBackButton: Navigator.canPop(context),
        onProfileClosed: () {
          _checkAuthAndLoad();
        },
      ),
      body: body,
      bottomNavigationBar: AppBottomBar(currentIndex: 3, user: _user),
    );
  }
}
