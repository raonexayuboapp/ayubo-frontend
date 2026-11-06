import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'auth_prompt_dialog.dart';
import '../screens/checkout_screen.dart';
import '../screens/vouchers_screen.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../utils/money.dart';

/// "Gift vouchers" on the Family page: a tile per amount on sale. It loads itself and stays hidden when there are
/// no amounts, so the page looks normal until staff create some.
class GiftVoucherSection extends StatefulWidget {
  final Map<String, dynamic> user;
  const GiftVoucherSection({super.key, required this.user});

  @override
  State<GiftVoucherSection> createState() => _GiftVoucherSectionState();
}

class _GiftVoucherSectionState extends State<GiftVoucherSection> {
  List<Map<String, dynamic>> _amounts = [];
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
      final amounts = await ApiService.instance.giftVoucherAmounts();
      if (!mounted) return;
      setState(() {
        _amounts = amounts;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _buy(Map<String, dynamic> amount) async {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: isDe ? 'Geschenkgutschein kaufen' : 'Purchase Gift Voucher',
        message: isDe
            ? 'Melden Sie sich an oder erstellen Sie ein Konto, um Geschenkgutscheine zu kaufen.'
            : 'Sign in or create an account to purchase gift vouchers.',
      );
      if (user == null || !mounted) return;
    }

    if (!mounted) return;

    final quantity = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BuySheet(amount: amount),
    );
    if (quantity == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.instance.addGiftVouchersToCart(amount['variant_id'] as int, quantity);
      CartState.instance.refresh(); // the badge on the cart tab
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(isDe
              ? 'In Ihren Warenkorb gelegt: $quantity × ${formatCents(amount['price_cents'] as int)} Geschenkgutschein.'
              : 'Added to your cart: $quantity × ${formatCents(amount['price_cents'] as int)} gift voucher.'),
          action: SnackBarAction(
            label: l10n?.proceedToCheckout ?? 'Checkout',
            onPressed: () {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(user: widget.user)));
            },
          ),
        ));
    } on ApiException catch (e) {
      if (e.statusCode != 401) {
        messenger.showSnackBar(SnackBar(content: Text(e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\n') : e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    if (_loading) return const SizedBox.shrink();
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(children: [
          Expanded(child: Text(isDe ? 'Geschenkgutscheine konnten nicht geladen werden.' : 'Gift vouchers could not be loaded.')),
          TextButton(onPressed: _load, child: Text(l10n?.retry ?? 'Retry')),
        ]),
      );
    }
    if (_amounts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n?.giftVouchers ?? 'Gift vouchers', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          isDe
              ? 'Verschenken Sie einen Gutschein. Er kann für alle Produkte im Shop eingelöst werden.'
              : 'Give someone a voucher. It can be used for any product in the shop.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final a in _amounts)
            SizedBox(
              width: 140,
              child: Card(
                key: ValueKey(a['variant_id']),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _buy(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    child: Column(children: [
                      Icon(Icons.card_giftcard_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(formatCents(a['price_cents'] as int), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(isDe ? 'Kaufen' : 'Buy', style: theme.textTheme.bodySmall),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VouchersScreen())),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(l10n?.myVouchers ?? 'My vouchers and credit'),
        ),
      ]),
    );
  }
}

/// Asks how many vouchers. Pops with the quantity, or with nothing on dismiss.
class _BuySheet extends StatefulWidget {
  final Map<String, dynamic> amount;
  const _BuySheet({required this.amount});

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  static const _max = 10;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = widget.amount['price_cents'] as int;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isDe ? 'Geschenkgutschein' : 'Gift voucher', style: theme.textTheme.titleMedium),
          Text(formatCents(price), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            isDe
                ? 'Sie erhalten den Gutscheincode per E-Mail, sobald die Bestellung bezahlt ist. Keine Lieferkosten, keine MwSt. Geben Sie den Code weiter oder fügen Sie ihn unter "Meine Gutscheine" Ihrem eigenen Konto hinzu. Gutscheine können für Produkte eingelöst werden.'
                : 'You get the voucher code by email as soon as the order is paid. No delivery, no shipping fee, no VAT. Give the code to someone, or add it to your own account under "My vouchers". Vouchers can pay for products, not for other vouchers or memberships.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text(isDe ? 'Menge' : 'How many'),
            const Spacer(),
            IconButton(
              tooltip: isDe ? 'Weniger' : 'Fewer',
              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(width: 32, child: Text('$_quantity', textAlign: TextAlign.center, style: theme.textTheme.titleMedium)),
            IconButton(
              tooltip: isDe ? 'Mehr' : 'More',
              onPressed: _quantity < _max ? () => setState(() => _quantity++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _quantity),
              child: Text(isDe
                  ? 'In den Warenkorb · ${formatCents(price * _quantity)}'
                  : 'Add to cart · ${formatCents(price * _quantity)}'),
            ),
          ),
        ]),
      ),
    );
  }
}
