import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import 'admin_membership_plan_form_screen.dart';

typedef PlanData = Map<String, dynamic>;

class AdminMembershipPlansScreen extends StatefulWidget {
  const AdminMembershipPlansScreen({super.key});

  @override
  State<AdminMembershipPlansScreen> createState() => _AdminMembershipPlansScreenState();
}

class _AdminMembershipPlansScreenState extends State<AdminMembershipPlansScreen> {
  List<PlanData> _plans = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

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

  Future<void> _toggle(PlanData plan) async {
    final theme = Theme.of(context);
    final id = plan['id'] as int;
    final active = plan['active'] == true;
    final members = plan['member_count'] as int;
    if (_busy.contains(id)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          active ? 'Deactivate plan?' : 'Activate plan?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          active
              ? '"${plan['name']}" can no longer be bought.'
                  '${members > 0 ? ' Its $members member${members == 1 ? '' : 's'} keep${members == 1 ? 's' : ''} the membership.' : ''}'
              : '"${plan['name']}" will be available to buy again.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: active ? Colors.redAccent : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Confirm'),
          ),
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

  String _benefitSummary(PlanData plan) {
    final benefits = (plan['benefits'] as List<dynamic>).cast<PlanData>();
    if (benefits.isEmpty) return 'No benefits';

    return benefits.map((b) {
      final code = b['code'] as String?;
      final name = code != null ? code.replaceAll('_', ' ') : (b['description'] as String? ?? 'Benefit');
      final d = b['discount_percent'] as num?;
      return d == null ? name : '${formatPercent(d)}% $name';
    }).join(', ');
  }

  Widget _tile(PlanData p) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final isDark = theme.brightness == Brightness.dark;
    final active = p['active'] == true;
    final hasProduct = p['has_product'] == true;
    final price = p['price_cents'] as int?;
    final members = p['member_count'] as int;
    final id = p['id'] as int;

    return ListTile(
      key: ValueKey(id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () => _openForm(id),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: goldColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.card_membership_outlined,
          color: goldColor,
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              p['name'] as String,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (!active) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Inactive',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          '${p['code']} · ${price == null ? 'no price' : formatCents(price)} · $members member${members == 1 ? '' : 's'}\n'
          '${_benefitSummary(p)}'
          '${hasProduct ? '' : '\nNot for sale: open it and set a price and tax rate.'}',
          style: hasProduct
              ? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))
              : theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      ),
      isThreeLine: true,
      trailing: Switch(
        value: active,
        activeColor: goldColor,
        onChanged: _busy.contains(id) ? null : (_) => _toggle(p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Widget body;

    if (_loading && _plans.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: goldColor));
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: goldColor),
                  foregroundColor: goldColor,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_plans.isEmpty) {
      body = Center(
        child: Text(
          'No plans yet.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: goldColor,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _plans.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
          itemBuilder: (_, i) => _tile(_plans[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership plans'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: goldColor,
        icon: const Icon(Icons.add),
        label: const Text(
          'New plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}