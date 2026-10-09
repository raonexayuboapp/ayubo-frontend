import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

/// Full details of one plan, with the Add to cart button.
class PlanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  const PlanDetailScreen({super.key, required this.plan});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool _adding = false;
  bool _added = false;

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      await ApiService.instance.addPlanToCart(widget.plan['id'] as int);
      if (!mounted) return;
      setState(() {
        _adding = false;
        _added = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${widget.plan['name']}" added to your cart.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      // e.g. 404 when an admin deactivated the plan while the page was open
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final theme = Theme.of(context);
    final benefits = (p['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final bonus = p['bonus_cents'] as int;
    final description = p['description'] as String?;
    final level = p['membership_level'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(p['name'] as String)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (level != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text(level.toUpperCase())),
            ),

          // The value of the voucher
          Text(formatCents(p['credit_cents'] as int),
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          Text('to spend on Ayubo products', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _row('You pay', formatCents(p['price_cents'] as int)),
                if (bonus > 0) _row('Bonus', '+ ${formatCents(bonus)}'),
                const Divider(),
                _row('You get', formatCents(p['credit_cents'] as int), bold: true),
                const SizedBox(height: 4),
                _row('Valid for', '${p['duration_months']} months'),
              ]),
            ),
          ),

          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(description),
          ],

          if (benefits.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Benefits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final b in benefits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(b['title'] as String),
                subtitle: (b['description'] as String?)?.isNotEmpty == true
                    ? Text(b['description'] as String)
                    : null,
                trailing: Text('${formatPercent(b['discount_percent'] as num)}% off',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],

          const SizedBox(height: 16),
          Text('How it works', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '• Your voucher balance can be spent in several purchases until it runs out.\n'
                '• The discount applies to the part of a purchase paid with the voucher.\n'
                '• Vouchers expire after the validity period and cannot be refunded or transferred.',
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _adding ? null : _addToCart,
            icon: _adding
                ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_shopping_cart),
            label: Text(_added ? 'Add another' : 'Add to cart'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}