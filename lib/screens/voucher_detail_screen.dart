import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/app_header.dart';
import '../widgets/voucher_state_chip.dart';

class VoucherDetailScreen extends StatefulWidget {
  final int voucherId;

  const VoucherDetailScreen({super.key, required this.voucherId});

  @override
  State<VoucherDetailScreen> createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends State<VoucherDetailScreen> {
  Map<String, dynamic>? _voucher;
  bool _loading = true;
  String? _error;

  // Always retrieve the currently active Flutter application locale.
  String get _locale => Localizations.localeOf(context).languageCode;

  bool get _isDe => _locale.startsWith('de');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _voucher == null;
      _error = null;
    });

    try {
      final voucher = await ApiService.instance.getVoucher(widget.voucherId);

      if (!mounted) return;

      setState(() {
        _voucher = voucher;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (_voucher == null) _error = e.message;
      });

      if (_voucher != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  String _label(String type, String? order) {
    switch (type) {
      case 'issue':
        return _isDe ? 'Hinzugefügt' : 'Added';

      case 'redeem':
        return order == null
            ? (_isDe ? 'Verwendet' : 'Used')
            : (_isDe
                  ? 'Verwendet für Bestellung $order'
                  : 'Used for order $order');

      case 'restore':
        return _isDe
            ? 'Zurückgebucht (Bestellung storniert)'
            : 'Returned (order cancelled)';

      case 'refund':
        return _isDe ? 'Zurückgebucht (Erstattung)' : 'Returned (refund)';

      case 'revoke':
        return _isDe ? 'Entzogen' : 'Withdrawn';

      default:
        return type.replaceAll('_', ' ');
    }
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );

  Widget _body() {
    final l10n = AppLocalizations.of(context);
    final locale = _locale;
    final isDe = locale.startsWith('de');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: Text(l10n?.retry ?? 'Retry')),
          ],
        ),
      );
    }

    final v = _voucher!;
    final theme = Theme.of(context);

    final isCredit = v['kind'] == 'membership_credit';
    final expires = v['expires_at'] as String?;
    final balance = (v['balance_cents'] as num?)?.toInt() ?? 0;
    final original = (v['original_cents'] as num?)?.toInt() ?? 0;

    final rawState = v['state'] as String? ?? 'available';

    final isExpired =
        expires != null &&
        DateTime.tryParse(expires)?.isBefore(DateTime.now()) == true;

    final String effectiveState;

    if (rawState == 'cancelled') {
      effectiveState = 'cancelled';
    } else if (rawState == 'expired' || isExpired) {
      effectiveState = 'expired';
    } else if (balance <= 0) {
      effectiveState = 'used';
    } else if (balance < original && balance > 0) {
      effectiveState = 'partially_redeemed';
    } else {
      effectiveState = rawState == 'active' ? 'available' : rawState;
    }

    final transactions = (v['transactions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final noExpiry = isDe ? 'Kein Verfall' : 'No expiry';

    final creditInfoText = isDe
        ? 'Dieses Guthaben wird automatisch verwendet, wenn Sie an der Kasse "Mit Mitgliedschaft bezahlen" wählen.'
        : 'This credit is used automatically when you choose "Pay with my membership" at checkout.';

    final voucherInfoText = isDe
        ? 'Der Gutscheincode wurde Ihnen per E-Mail zugesandt, als Sie bestellt haben. Aus Sicherheitsgründen wird er nicht erneut angezeigt.'
        : 'The voucher code was emailed to you when you ordered. For your security it is never shown again.';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    isCredit
                        ? (l10n?.membershipCredit ?? 'Membership credit')
                        : '${l10n?.giftVoucher ?? 'Gift voucher'} •••• ${v['suffix']}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    formatCents(balance, locale),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    l10n?.remainingBalance ?? 'remaining balance',
                    style: theme.textTheme.bodySmall,
                  ),

                  const SizedBox(height: 8),

                  VoucherStateChip(state: effectiveState, locale: locale),

                  const Divider(height: 28),

                  _info(
                    l10n?.originalValue ?? 'Original value',
                    formatCents(original, locale),
                  ),

                  if (balance < original && balance > 0)
                    _info(
                      l10n?.redeemedSoFar ?? 'Redeemed so far',
                      formatCents(original - balance, locale),
                    ),

                  _info(
                    l10n?.validUntil ?? 'Valid until',
                    expires == null ? noExpiry : formatDate(expires, locale),
                  ),

                  _info(
                    l10n?.added ?? 'Added',
                    formatDate(v['created_at'] as String?, locale),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            isCredit ? creditInfoText : voucherInfoText,
            style: theme.textTheme.bodySmall,
          ),

          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              l10n?.transactionHistory ?? 'History',
              style: theme.textTheme.titleMedium,
            ),
          ),

          if (transactions.isEmpty)
            Text(
              l10n?.noVoucherHistory ??
                  'Nothing has happened with this voucher yet.',
            ),

          for (final t in transactions) _transaction(t),
        ],
      ),
    );
  }

  Widget _transaction(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final locale = _locale;

    final amount = (t['amount_cents'] as num).toInt();
    final positive = amount > 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,

      title: Text(_label(t['type'] as String, t['order_number'] as String?)),

      subtitle: Text(formatDateTime(t['created_at'] as String?, locale)),

      trailing: Text(
        '${positive ? '+' : '−'}${formatCents(amount.abs(), locale)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: positive ? Colors.green.shade700 : theme.colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.giftVouchers ?? 'Gift Vouchers',
        subtitle: l10n?.voucherDetailsSubtitle ?? 'Details & Balance',
        showBackButton: true,
      ),
      body: _body(),
    );
  }
}
