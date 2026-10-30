import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
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

  Widget _card(Map<String, dynamic> v) {
    final theme = Theme.of(context);
    final isCredit = v['kind'] == 'membership_credit';
    final expires = v['expires_at'] as String?;
    final value = formatCents(v['original_cents'] as int);

    return Card(
      key: ValueKey(v['id']),
      child: ListTile(
        onTap: () => _open(v),
        leading: Icon(isCredit ? Icons.account_balance_wallet_outlined : Icons.card_giftcard_outlined),
        title: Text(isCredit ? 'Membership credit' : 'Gift voucher •••• ${v['suffix']}'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Value $value · ${expires == null ? 'no expiry' : 'valid until ${formatDate(expires)}'}'),
          const SizedBox(height: 4),
          VoucherStateChip(state: v['state'] as String),
        ]),
        isThreeLine: true,
        trailing: Text(formatCents(v['balance_cents'] as int),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else if (_items.isEmpty) {
      // A scrollable, so pull-to-refresh still works on an empty list.
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(children: const [
          SizedBox(height: 160),
          Center(
            child: Text('You have no vouchers yet.\nGift vouchers you buy and your membership credit appear here.',
                textAlign: TextAlign.center),
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
                child: const Text('Load more'),
              );
            }
            return _card(_items[i]);
          },
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('My vouchers and credit')), body: body);
  }
}