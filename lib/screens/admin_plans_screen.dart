import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import 'admin_plan_form_screen.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  List<Map<String, dynamic>> _plans = [];
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
      final plans = await ApiService.instance.adminListPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? plan]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminPlanFormScreen(plan: plan)),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> plan) async {
    final active = plan['is_active'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(active ? 'Deactivate plan?' : 'Activate plan?'),
        content: Text(active
            ? '"${plan['name']}" can no longer be bought. Vouchers already sold keep working.'
            : '"${plan['name']}" will be available to buy again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.instance.adminUpdatePlan(plan['id'] as int, {'is_active': !active});
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
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
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _plans[i];
          final active = p['is_active'] == true;
          final benefits = (p['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();

          return Card(
            child: ListTile(
              onTap: () => _openForm(p),
              title: Row(children: [
                Flexible(child: Text(p['name'] as String)),
                if (!active) ...[
                  const SizedBox(width: 8),
                  const Chip(label: Text('Inactive'), visualDensity: VisualDensity.compact),
                ],
              ]),
              subtitle: Text(
                '${formatCents(p['price_cents'] as int)} + ${formatCents(p['bonus_cents'] as int)} bonus '
                    '= ${formatCents(p['credit_cents'] as int)} credit\n'
                    '${p['duration_months']} months'
                    '${benefits.isEmpty ? '' : '\n${benefits.map((b) => '${b['discount_percent']}% ${b['title']}').join(', ')}'}',
              ),
              isThreeLine: true,
              trailing: Switch(value: active, onChanged: (_) => _toggleActive(p)),
            ),
          );
        },
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