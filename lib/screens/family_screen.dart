import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../utils/membership_style.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/benefit_line.dart';
import 'membership_plan_screen.dart';
import 'vouchers_screen.dart';

class FamilyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const FamilyScreen({super.key, required this.user});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  static const _previewCount = 4; // benefits shown on a card; the detail page shows all of them

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

  Future<void> _open(Map<String, dynamic> plan, Color accent) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MembershipPlanScreen(plan: plan, membership: _membership, user: widget.user, accent: accent),
      ),
    );
    if (mounted) _load(); // the membership may have changed on the way (for example it was bought on the website)
  }

  Widget _banner() {
    final m = _membership;
    if (m == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final status = m['status'] as String;
    final benefits = ((m['benefits'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
    final credit = (m['credit_cents'] as num?)?.toInt() ?? 0;
    final discount = m['discount_percent'] as num?;

    final (icon, text) = switch (status) {
      'active' => (
      Icons.verified_outlined,
      'You are an Ayubo Family member (${m['plan_name']}).\nMember number ${m['member_number']}'
      ),
      'suspended' => (Icons.pause_circle_outline, 'Your membership is suspended. Please contact support.'),
      _ => (Icons.info_outline, 'Your membership is not active (your credit is used up). You can join again below.'),
    };

    Widget figure(String value, String label) => Expanded(
      child: Column(children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ]),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
          if (status == 'active') ...[
            const Divider(height: 24),
            Row(children: [
              figure(formatCents(credit), 'shopping credit'),
              if (discount != null) figure('${formatPercent(discount)}%', 'member discount'),
            ]),
          ],
          if (status == 'active' && benefits.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Your benefits', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final b in benefits)
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: BenefitLine(benefit: b)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const VouchersScreen()));
                if (mounted) _load(); // the credit may have changed
              },
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('My vouchers and credit'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> p, int rank) {
    final theme = Theme.of(context);
    final accent = tierColor(rank);
    final tagline = p['description'] as String?;
    final benefits = (p['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final shown = benefits.take(_previewCount).toList();
    final more = benefits.length - shown.length;

    return Card(
      clipBehavior: Clip.antiAlias, // keeps the tap ripple inside the rounded corners
      child: InkWell(
        onTap: () => _open(p, accent),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.circle, size: 14, color: accent),
              const SizedBox(width: 8),
              Expanded(child: Text(p['name'] as String, style: theme.textTheme.titleLarge)),
            ]),
            const SizedBox(height: 4),
            Text(formatCents(p['price_cents'] as int),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('incl. VAT', style: theme.textTheme.bodySmall),
            if (tagline != null && tagline.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tagline, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (shown.isNotEmpty) ...[
              const Divider(height: 24),
              for (final b in shown)
                Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: BenefitLine(benefit: b, color: accent)),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 30),
                  child: Text('+ $more more', style: theme.textTheme.bodySmall),
                ),
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
      final plans = _plans; // the server sorts them cheapest first, which decides each tier's colour
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
            for (var i = 0; i < plans.length; i++)
              Padding(padding: const EdgeInsets.only(top: 12), child: _planCard(plans[i], i)),
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