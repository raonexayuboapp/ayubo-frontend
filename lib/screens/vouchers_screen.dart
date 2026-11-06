import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/app_header.dart';
import '../widgets/prompt_dialog.dart';
import '../widgets/voucher_state_chip.dart';
import 'voucher_detail_screen.dart';

/// Gift vouchers the customer bought or owns, and the shopping credit of their membership.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
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
      final data = await ApiService.instance.listVouchers(page: _page);
      final list = (data['vouchers'] as List<dynamic>).cast<Map<String, dynamic>>();
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
      if (!reset) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(Map<String, dynamic> v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VoucherDetailScreen(voucherId: v['id'] as int)),
    );
    if (mounted) _load(reset: true);
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    final r = await showPrompt(
      context,
      title: isDe ? 'Gutschein hinzufügen' : 'Add a voucher',
      message: isDe
          ? 'Geben Sie den Gutscheincode aus Ihrer E-Mail oder von Ihrer Gutscheinkarte ein. Der Gutschein wird Ihrem Konto gutgeschrieben.'
          : 'Enter the code from your email or voucher card. The voucher is added to your account, and only you can use it from then on.',
      confirmLabel: isDe ? 'Gutschein einlösen' : 'Add voucher',
      fields: [PromptField(key: 'code', label: l10n?.voucherCode ?? 'Voucher code', required: true, maxLength: 40)],
    );
    if (r == null) return;

    try {
      final result = await ApiService.instance.claimVoucher(r['code']!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDe
              ? 'Gutschein hinzugefügt. Guthaben: ${formatCents((result['balance_cents'] as num).toInt())}.'
              : 'Voucher added. Balance ${formatCents((result['balance_cents'] as num).toInt())}.'),
        ),
      );
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\n') : e.message)),
      );
    }
  }

  Widget _card(Map<String, dynamic> v) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    final isCredit = v['kind'] == 'membership_credit';
    final expires = v['expires_at'] as String?;
    final balanceCents = (v['balance_cents'] as num?)?.toInt() ?? 0;
    final originalCents = (v['original_cents'] as num?)?.toInt() ?? 0;
    final rawState = v['state'] as String? ?? 'active';

    final effectiveState = switch (rawState) {
      'active' when balanceCents > 0 && balanceCents < originalCents => 'partially_redeemed',
      'active' when balanceCents >= originalCents => 'available',
      _ => rawState,
    };

    final value = formatCents(originalCents);

    return Card(
      key: ValueKey(v['id']),
      child: ListTile(
        onTap: () => _open(v),
        leading: Icon(isCredit ? Icons.account_balance_wallet_outlined : Icons.card_giftcard_outlined),
        title: Text(isCredit
            ? (isDe ? 'Mitgliedschaftsguthaben' : 'Membership credit')
            : (isDe ? 'Geschenkgutschein •••• ${v['suffix']}' : 'Gift voucher •••• ${v['suffix']}')),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${isDe ? 'Wert' : 'Value'} $value · ${expires == null ? (l10n?.neverExpires ?? 'no expiry') : (isDe ? 'gültig bis ${formatDate(expires)}' : 'valid until ${formatDate(expires)}') }'),
          const SizedBox(height: 4),
          VoucherStateChip(state: effectiveState),
        ]),
        isThreeLine: true,
        trailing: Text(formatCents(balanceCents),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: Text(l10n?.retry ?? 'Retry')),
        ]),
      );
    } else if (_items.isEmpty) {
      // A scrollable, so pull-to-refresh still works on an empty list.
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(children: [
          const SizedBox(height: 160),
          Center(
            child: Text(
              l10n?.noVouchersYet ??
                  'You have no vouchers yet.\nGift vouchers you buy and your membership credit appear here.',
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      );
    } else {
      final hasMore = _items.length < _total;
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
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
                child: Text(l10n?.loadMore ?? 'Load more'),
              );
            }
            return _card(_items[i]);
          },
        ),
      );
    }

    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.myVouchers ?? 'My Vouchers & Credit',
        subtitle: isDe ? 'Guthaben & Geschenkgutscheine' : 'Wallet balance & gift vouchers',
        showBackButton: true,
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.brandGold,
        elevation: 2,
        onPressed: _add,
        icon: const Icon(Icons.qr_code_rounded, size: 18),
        label: Text(
          l10n?.claimVoucher ?? 'Add a voucher',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
