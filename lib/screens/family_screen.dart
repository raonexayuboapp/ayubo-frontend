import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';

class FamilyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const FamilyScreen({super.key, required this.user});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  // ASSUMPTION, the same as on the server: a member whose status is one of these cannot join again.
  // Confirm the status words with the supervisor. Any other status (for example when the credit ran out)
  // lets the customer join again.
  static const _blockingStatuses = {'active', 'suspended'};

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final Set<int> _joining = {}; // variant ids with a request in flight

  List<Map<String, dynamic>> get _plans => ((_data?['plans'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _membership => _data?['membership'] as Map<String, dynamic>?;

  bool get _cannotJoin => _membership != null && _blockingStatuses.contains(_membership!['status']);

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
      final data = await ApiService.instance.membershipPlans();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_data == null) _error = e.message;
      });
      if (_data != null) _snack(e.message);
    }
  }

  Future<void> _join(Map<String, dynamic> plan) async {
    final variantId = plan['variant_id'] as int;
    if (_joining.contains(variantId)) return;

    setState(() => _joining.add(variantId));
    try {
      await ApiService.instance.addToCart(variantId, 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('"${plan['name']}" added to your cart.'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              if (mounted) AppBottomBar.open(context, 3, widget.user);
            },
          ),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
      _load(); // the membership may have changed (for example the customer joined on the website)
    } finally {
      if (mounted) setState(() => _joining.remove(variantId));
    }
  }

  Widget _banner() {
    final m = _membership;
    if (m == null) return const SizedBox.shrink();

    final (icon, text) = switch (m['status'] as String) {
      'active' => (
      Icons.verified_outlined,
      'You are an Ayubo Family member (${m['plan_name']}).\nMember number ${m['member_number']}'
      ),
      'suspended' => (Icons.pause_circle_outline, 'Your membership is suspended. Please contact support.'),
      _ => (Icons.info_outline, 'Your membership is not active. You can join again below.'),
    };

    return Card(child: ListTile(leading: Icon(icon), title: Text(text)));
  }

  Widget _planCard(Map<String, dynamic> p) {
    final theme = Theme.of(context);
    final description = p['description'] as String?;
    final benefits = (p['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final busy = _joining.contains(p['variant_id'] as int);
    final price = formatCents(p['price_cents'] as int);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['name'] as String, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(price, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('incl. VAT', style: theme.textTheme.bodySmall),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],
          if (benefits.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Benefits', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final b in benefits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b['description'] as String)),
                ]),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _cannotJoin || busy ? null : () => _join(p),
              icon: busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_shopping_cart),
              label: Text('Join for $price'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _data == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else {
      final plans = _plans;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _banner(),
            if (plans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No membership is available right now.')),
              ),
            for (final p in plans)
              Padding(padding: const EdgeInsets.only(top: 12), child: _planCard(p)),
            const SizedBox(height: 12),
            Text(
              'Your membership starts when your order is paid. The credit and discounts are shown here once it is active.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppTopBar(user: widget.user),
      body: body,
      bottomNavigationBar: AppBottomBar(currentIndex: 2, user: widget.user),
    );
  }
}