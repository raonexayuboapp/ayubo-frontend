import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import 'membership_plan_screen.dart';

class FamilyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const FamilyScreen({super.key, required this.user});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get _plans =>
      ((_data?['plans'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _membership => _data?['membership'] as Map<String, dynamic>?;

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
      if (_data != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(Map<String, dynamic> plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MembershipPlanScreen(plan: plan, membership: _membership, user: widget.user),
      ),
    );
    if (mounted) _load(); // the membership may have changed on the way (for example it was bought on the website)
  }

  /// The highest discount among a plan's benefits, or null if none of them has one.
  num? _topDiscount(Map<String, dynamic> plan) {
    final discounts = (plan['benefits'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((b) => b['discount_percent'] as num?)
        .whereType<num>();

    return discounts.isEmpty ? null : discounts.reduce((a, b) => a > b ? a : b);
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
    final top = _topDiscount(p);

    return Card(
      clipBehavior: Clip.antiAlias, // keeps the tap ripple inside the rounded corners
      child: InkWell(
        onTap: () => _open(p),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] as String, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(formatCents(p['price_cents'] as int),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('incl. VAT', style: theme.textTheme.bodySmall),
            if (top != null) ...[
              const SizedBox(height: 8),
              Text('Member discount up to ${formatPercent(top)}%'),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('View details', style: TextStyle(color: theme.colorScheme.primary)),
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            ]),
          ]),
        ),
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
            for (final p in plans) Padding(padding: const EdgeInsets.only(top: 12), child: _planCard(p)),
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