import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/voucher_state_chip.dart';
import 'admin_voucher_detail_screen.dart';
import 'admin_voucher_issue_screen.dart';

class AdminVouchersScreen extends StatefulWidget {
  const AdminVouchersScreen({super.key});

  @override
  State<AdminVouchersScreen> createState() => _AdminVouchersScreenState();
}

class _AdminVouchersScreenState extends State<AdminVouchersScreen> {
  static const _states = ['', 'active', 'used', 'expired', 'cancelled'];
  static const _kinds = ['', 'issued', 'purchased', 'membership_credit'];

  final _search = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _items = [];
  String _state = '';
  String _kind = '';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;
  int _request = 0; // an answer that belongs to an older search is ignored

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final request = ++_request;
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.adminListVouchers(
        state: _state,
        kind: _kind,
        search: _search.text.trim(),
        page: _page,
      );
      if (!mounted || request != _request) return;

      final list = (data['vouchers'] as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() {
        _items = reset ? list : [..._items, ...list];
        _total = (data['meta'] as Map<String, dynamic>)['total'] as int;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) return;
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

  void _onSearchChanged(String _) {
    setState(() {}); // shows or hides the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _open(Map<String, dynamic> v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminVoucherDetailScreen(voucherId: v['id'] as int)),
    );
    if (mounted) _load(reset: true);
  }

  Future<void> _issue() async {
    final issued = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AdminVoucherIssueScreen()));
    if (issued == true && mounted) _load(reset: true);
  }

  Widget _chips(List<String> values, String selected, String Function(String) label, ValueChanged<String> onSelected) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(v.isEmpty ? 'All' : label(v)),
                selected: selected == v,
                onSelected: (_) => onSelected(v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> v) {
    final theme = Theme.of(context);
    final owner = v['owner'] as Map<String, dynamic>?;
    final expires = v['expires_at'] as String?;
    final kind = v['kind'] as String;

    return Card(
      key: ValueKey(v['id']),
      child: ListTile(
        onTap: () => _open(v),
        leading: Icon(kind == 'membership_credit' ? Icons.account_balance_wallet_outlined : Icons.card_giftcard_outlined),
        title: Text('•••• ${v['suffix']}  ·  ${voucherKindLabel(kind)}'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(owner == null ? 'No owner yet' : '${owner['name']} · ${owner['email']}'),
          Text(
            'Value ${formatCents(v['original_cents'] as int)} · ${expires == null ? 'no expiry' : 'until ${formatDate(expires)}'}'
            '${v['order_number'] == null ? '' : ' · ${v['order_number']}'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          VoucherStateChip(state: v['state'] as String),
        ]),
        isThreeLine: true,
        trailing: Text(formatCents(v['balance_cents'] as int),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(children: const [SizedBox(height: 140), Center(child: Text('No vouchers found.'))]),
      );
    }

    final hasMore = _items.length < _total;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vouchers ($_total)')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _load(reset: true),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Last 4 of the code, owner email, order number',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        _load(reset: true);
                      },
                    ),
            ),
          ),
        ),
        _chips(_states, _state, voucherStateLabel, (v) {
          setState(() => _state = v);
          _load(reset: true);
        }),
        _chips(_kinds, _kind, voucherKindLabel, (v) {
          setState(() => _kind = v);
          _load(reset: true);
        }),
        Expanded(child: _body()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _issue,
        icon: const Icon(Icons.add),
        label: const Text('Issue vouchers'),
      ),
    );
  }
}