import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import 'plan_detail_screen.dart';

/// The Family tab: a short list of plans. Details and "Add to cart" live on the detail screen.
class FamilyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const FamilyScreen({super.key, required this.user});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
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
      final plans = await ApiService.instance.listMembershipPlans();
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

  /// The highest discount among a plan's benefits, or null if it has none.
  num? _topDiscount(Map<String, dynamic> plan) {
    final benefits = (plan['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();
    if (benefits.isEmpty) return null;
    return benefits.map((b) => b['discount_percent'] as num).reduce((a, b) => a > b ? a : b);
  }

  Widget _planCard(Map<String, dynamic> p) {
    final theme = Theme.of(context);
    final level = p['membership_level'] as String?;
    final top = _topDiscount(p);

    return Card(
      clipBehavior: Clip.antiAlias, // keeps the tap ripple inside the rounded corners
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: p)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(p['name'] as String, style: theme.textTheme.titleLarge)),
                if (level != null)
                  Chip(label: Text(level.toUpperCase()), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 8),
              Text(
                'Pay ${formatCents(p['price_cents'] as int)}, '
                    'get ${formatCents(p['credit_cents'] as int)} to spend',
                style: theme.textTheme.titleMedium,
              ),
              if (top != null) ...[
                const SizedBox(height: 4),
                Text('Up to ${formatPercent(top)}% off your purchases'),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('View details', style: TextStyle(color: theme.colorScheme.primary)),
                  Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
      body = const Center(child: Text('No membership plans available right now.'));
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _planCard(_plans[i]),
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