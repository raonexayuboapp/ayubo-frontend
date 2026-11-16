import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/benefit_line.dart';

typedef PlanData = Map<String, dynamic>;

/// One plan in full, with every benefit and the Join button (which adds the membership to the cart).
class MembershipPlanScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? membership; // customer's own membership, if any
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

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String? get _membershipStatus {
    final raw = widget.membership?['status'];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim().toLowerCase();
  }

  /// Keep the frontend aligned with the backend purchase rules:
  /// active, paused and cancelled memberships block another purchase;
  /// inactive and expired memberships do not.
  String? _membershipPurchaseBlockedMessage() {
    if (widget.membership == null) return null;

    switch (_membershipStatus) {
      case 'active':
        return 'You already have an active membership. You can join another plan after your shopping credit is used or your membership expires.';
      case 'paused':
        return 'Your membership is paused. You cannot purchase another membership while it is paused.';
      case 'cancelled':
        return 'Your membership has been cancelled. You cannot purchase another membership at this time.';
      case 'inactive':
      case 'expired':
        return null;
      default:
        // Fail closed if the backend introduces a status this screen does not know.
        return 'Your membership status could not be verified. Please refresh your membership details before purchasing another plan.';
    }
  }

  String? _membershipStatusLabel() {
    switch (_membershipStatus) {
      case 'active':
        return 'Active membership';
      case 'inactive':
        return 'Credit used';
      case 'paused':
        return 'Paused';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return 'Membership status unavailable';
    }
  }

  String? _membershipStatusDescription() {
    switch (_membershipStatus) {
      case 'active':
        return 'Your membership is active. You can use your available shopping credit at checkout. Another membership can be purchased after the credit is fully used or the membership expires.';
      case 'inactive':
        return 'Your shopping credit has been fully used. You can purchase a new membership.';
      case 'paused':
        return 'Your membership is paused. Another membership cannot be purchased while it remains paused.';
      case 'cancelled':
        return 'This membership has been cancelled. Contact support if you need help with your membership.';
      case 'expired':
        return 'Your membership has expired. You can choose and purchase a new membership.';
      default:
        return 'Your membership is on record, but its current status could not be identified. Please refresh your membership details.';
    }
  }

  Future<void> _join() async {
    if (_joining) return;

    final blocked = _membershipPurchaseBlockedMessage();
    if (blocked != null) {
      _snack(blocked);
      return;
    }

    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'Join Ayubo Family',
        message:
            'Sign in or create an account to join the ${widget.plan['name']} membership plan.',
      );
      if (user == null || !mounted) return;
    }

    setState(() => _joining = true);
    try {
      final planId = (widget.plan['id'] as num?)?.toInt();
      final variantId = (widget.plan['variant_id'] as num?)?.toInt();

      if (planId != null) {
        await ApiService.instance.purchaseMembership(planId);
      } else if (variantId != null) {
        await ApiService.instance.addToCart(variantId, 1);
      } else {
        _snack('This plan is not available for purchase online.');
        return;
      }

      if (!mounted) return;
      CartState.instance.refresh();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('"${widget.plan['name']}" added to your cart.'),
            action: SnackBarAction(
              label: 'View cart',
              textColor: Theme.of(context).colorScheme.secondary,
              onPressed: () {
                if (mounted) AppBottomBar.open(context, 3, widget.user);
              },
            ),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 409) {
        // Reconcile the cart if backend eligibility changed since this screen opened.
        CartState.instance.refresh();
      }

      if (e.statusCode != 401) _snack(e.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final tagline = p['description'] as String?;
    final benefits = (p['benefits'] as List<dynamic>).cast<PlanData>();
    final blocked = _membershipPurchaseBlockedMessage();
    final priceCents = (p['price_cents'] as num?)?.toInt();
    final price = priceCents != null
        ? formatCents(priceCents)
        : 'Price unavailable';
    final membershipStatusLabel = widget.membership == null
        ? null
        : _membershipStatusLabel();
    final membershipStatusDescription = widget.membership == null
        ? null
        : _membershipStatusDescription();

    return Scaffold(
      appBar: AppHeader(
        title: p['name'] as String,
        subtitle: 'Membership Tier',
        user: widget.user,
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p['name'] as String,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: goldColor,
            ),
          ),
          Text(
            'incl. VAT',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (tagline != null && tagline.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tagline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (membershipStatusLabel != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membershipStatusLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (membershipStatusDescription != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      membershipStatusDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'What you get',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: benefits.isEmpty
                  ? Text(
                      'No benefits are listed for this membership yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final b in benefits)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: BenefitLine(
                              benefit: b,
                              color: widget.accent,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your membership starts when your order is paid.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed:
                blocked != null ||
                    priceCents == null ||
                    priceCents <= 0 ||
                    _joining
                ? null
                : _join,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: goldColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _joining
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: goldColor,
                    ),
                  )
                : const Icon(Icons.add_shopping_cart, size: 20),
            label: Text(
              blocked != null
                  ? 'Membership purchase unavailable'
                  : 'Join for $price',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (blocked != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                blocked,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            )
          else if (priceCents == null || priceCents <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This plan is currently unavailable for purchase.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
