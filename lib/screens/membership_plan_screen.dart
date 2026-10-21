import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/membership_status.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/benefit_line.dart';

/// One plan in full, with every benefit and the Join button (which adds the membership to the cart).
class MembershipPlanScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? membership; // the customer's own membership, if any
  final Map<String, dynamic> user;
  final Color accent;

  const MembershipPlanScreen({
    super.key,
    required this.plan,
    required this.membership,
    required this.user,
    required this.accent,
  });

  @override
  State<MembershipPlanScreen> createState() => _MembershipPlanScreenState();
}

class _MembershipPlanScreenState extends State<MembershipPlanScreen> {
  bool _joining = false;

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _join() async {
    if (_joining) return; // ignore a second tap while the first is still being sent

    setState(() => _joining = true);
    try {
      await ApiService.instance.addToCart(widget.plan['variant_id'] as int, 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('"${widget.plan['name']}" added to your cart.'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              if (mounted) AppBottomBar.open(context, 3, widget.user);
            },
          ),
        ));
    } on ApiException catch (e) {
      if (mounted) _snack(e.message); // for example: you are already a member
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final theme = Theme.of(context);
    final tagline = p['description'] as String?;
    final benefits = (p['benefits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final blocked = joinBlockedMessage(widget.membership);
    final price = formatCents(p['price_cents'] as int);

    return Scaffold(
      appBar: AppBar(title: Text(p['name'] as String)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(children: [
            Icon(Icons.circle, size: 18, color: widget.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(p['name'] as String, style: theme.textTheme.headlineSmall)),
          ]),
          const SizedBox(height: 12),
          Text(price, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          Text('incl. VAT', style: theme.textTheme.bodySmall),
          if (tagline != null && tagline.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tagline, style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 24),
          Text('What you get', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: widget.accent, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: benefits.isEmpty
                  ? const Text('No benefits are listed for this membership yet.')
                  : Column(children: [
                for (final b in benefits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: BenefitLine(benefit: b, color: widget.accent),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Your membership starts when your order is paid.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: blocked != null || _joining ? null : _join,
            icon: _joining
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_shopping_cart),
            label: Text('Join for $price'),
          ),
          if (blocked != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(blocked, style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
    );
  }
}