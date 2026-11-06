import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/app_header.dart';

typedef LoyaltyTransactionData = Map<String, dynamic>;

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  List<LoyaltyTransactionData> _items = [];
  int _balance = 0;
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
      final data = await ApiService.instance.loyalty(page: _page);
      final list = (data['transactions'] as List<dynamic>).cast<LoyaltyTransactionData>();
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num).toInt();
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
          _page--;
        }
      });
      if (!reset) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _label(String type) {
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');
    switch (type) {
      case 'earn':
        return l10n?.pointsEarned ?? (isDe ? 'Punkte gesammelt' : 'Points earned');
      case 'reverse':
        return l10n?.pointsRefunded ?? (isDe ? 'Punkte zurückgebucht (Erstattung)' : 'Points taken back (refund)');
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Widget _header() {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goldColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: goldColor.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.stars_rounded,
              size: 40,
              color: goldColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$_balance',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            l10n?.availablePoints ?? 'AVAILABLE POINTS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: goldColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          Text(
            l10n?.loyaltyExplanation ??
                'You earn points on the money you pay for an order. Points are added when the order is paid.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(LoyaltyTransactionData t) {
    final theme = Theme.of(context);
    final points = t['points'] as int;
    final positive = points > 0;
    final order = t['order_number'] as String?;
    final l10n = AppLocalizations.of(context);
    final isDe = (l10n?.localeName ?? currentAppLocale).startsWith('de');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(t['type'] as String),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (order != null) (isDe ? 'Bestellung $order' : 'Order $order'),
                    formatDate(t['created_at'] as String?),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : '−'}${points.abs()}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: positive ? Colors.green.shade600 : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    Widget body;

    if (_loading && _items.isEmpty && _total == 0 && _balance == 0) {
      body = Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    } else if (_error != null) {
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
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n?.retry ?? 'Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    } else {
      final hasMore = _items.length < _total;
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: goldColor,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Text(
                l10n?.transactionHistory ?? 'Transaction History',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    l10n?.noPointsYet ?? 'No points yet. Your first order will earn some.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            for (final t in _items) _row(t),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: _loading
                      ? CircularProgressIndicator(color: goldColor, strokeWidth: 2)
                      : TextButton(
                          onPressed: () {
                            _page++;
                            _load(reset: false);
                          },
                          child: Text(
                            l10n?.loadMore ?? 'Load more',
                            style: TextStyle(color: goldColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
              ),
          ],
        ),
      );
    }

    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.loyaltyRewards ?? 'Ayubo Loyalty Rewards',
        subtitle: isDe ? 'Punkte & Belohnungsstufen' : 'Points & reward tiers',
        showBackButton: true,
      ),
      body: body,
    );
  }
}
