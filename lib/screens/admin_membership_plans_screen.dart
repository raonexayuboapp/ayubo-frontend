import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import 'admin_membership_plan_form_screen.dart';

class AdminMembershipPlansScreen extends StatefulWidget {
  const AdminMembershipPlansScreen({super.key});

  @override
  State<AdminMembershipPlansScreen> createState() => _AdminMembershipPlansScreenState();
}

class _AdminMembershipPlansScreenState extends State<AdminMembershipPlansScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {}; // plan ids with a request in flight

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
      final plans = await ApiService.instance.adminMembershipPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_plans.isEmpty) _error = e.message;
      });
      if (_plans.isNotEmpty) _snack(e.message);
    }
  }

  Future<void> _openForm([int? id]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminMembershipPlanFormScreen(planId: id)),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> plan) async {
    final id = plan['id'] as int;
    final active = plan['active'] == true;
    final members = plan['member_count'] as int;
    if (_busy.contains(id)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(active ? 'Deactivate plan?' : 'Activate plan?'),
        content: Text(active
            ? '"${plan['name']}" can no longer be bought.'
            '${members > 0 ? ' Its $members member${members == 1 ? '' : 's'} keep${members == 1 ? 's' : ''} the membership.' : ''}'
            : '"${plan['name']}" will be available to buy again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy.add(id));
    try {
      await ApiService.instance.adminUpdateMembershipPlan(id, {'active': !active});
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  String _benefitSummary(Map<String, dynamic> plan) {
    final benefits = (plan['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();
    if (benefits.isEmpty) return 'No benefits';

    return benefits.map((b) {
      final name = (b['code'] as String).replaceAll('_', ' ');
      final d = b['discount_percent'] as num?;
      return d == null ? name : '${formatPercent(d)}% $name';
    }).join(', ');
  }

  Widget _tile(Map<String, dynamic> p) {
    final theme = Theme.of(context);
    final active = p['active'] == true;
    final hasProduct = p['has_product'] == true;
    final price = p['price_cents'] as int?;
    final members = p['member_count'] as int;
    final id = p['id'] as int;

    return ListTile(
      key: ValueKey(id),
      onTap: () => _openForm(id),
      title: Row(children: [
        Flexible(child: Text(p['name'] as String)),
        if (!active) ...[
          const SizedBox(width: 8),
          const Chip(label: Text('Inactive'), visualDensity: VisualDensity.compact),
        ],
      ]),
      subtitle: Text(
        '${p['code']} · ${price == null ? 'no price' : formatCents(price)} · $members member${members == 1 ? '' : 's'}\n'
            '${_benefitSummary(p)}'
            '${hasProduct ? '' : '\nNot for sale: open it and set a price and tax rate.'}',
        style: hasProduct ? null : TextStyle(color: theme.colorScheme.error),
      ),
      isThreeLine: true,
      trailing: Switch(value: active, onChanged: _busy.contains(id) ? null : (_) => _toggle(p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading && _plans.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else if (_plans.isEmpty) {
      body = const Center(child: Text('No plans yet.'));
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _plans.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _tile(_plans[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Membership plans')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
    );
  }
}