import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/benefit_line.dart';

typedef PlanData = Map<String, dynamic>;

/// One plan in full, with every benefit and the Join button
/// (which adds the membership to the cart).
class MembershipPlanScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? membership;
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
  late PlanData _plan;
  bool _joining = false;
  String? _loadedLanguage;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _plan = Map<String, dynamic>.from(widget.plan);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final language = Localizations.localeOf(context).languageCode.toLowerCase();

    if (_loadedLanguage == null) {
      _loadedLanguage = language;
    } else if (_loadedLanguage != language) {
      _loadedLanguage = language;
      _refreshPlan();
    }
  }

  Future<void> _refreshPlan() async {
    final planId = (_plan['id'] as num?)?.toInt();
    if (planId == null) return;

    final requestId = ++_loadRequestId;

    try {
      final data = await ApiService.instance.membershipPlans();

      if (!mounted || requestId != _loadRequestId) return;

      final plans = (data['plans'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();

      for (final plan in plans) {
        if ((plan['id'] as num?)?.toInt() == planId) {
          setState(() {
            _plan = Map<String, dynamic>.from(plan);
          });
          return;
        }
      }
    } catch (_) {
      // Keep the currently displayed plan if refreshing fails.
    }
  }

  bool get _isDe =>
      AppLocalizations.of(context)?.localeName.startsWith('de') ?? false;

  String _text(String en, String de) => _isDe ? de : en;

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String? get _membershipStatus {
    final raw = widget.membership?['status'];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim().toLowerCase();
  }

  /// Keep the frontend aligned with backend purchase rules:
  /// active, paused and cancelled memberships block another purchase;
  /// inactive and expired memberships do not.
  String? _membershipPurchaseBlockedMessage() {
    if (widget.membership == null) return null;

    switch (_membershipStatus) {
      case 'active':
        return _text(
          'You already have an active membership. You can join another plan after your shopping credit is used or your membership expires.',
          'Sie haben bereits eine aktive Mitgliedschaft. Sie können einen weiteren Plan erwerben, sobald Ihr Einkaufsguthaben aufgebraucht ist oder Ihre Mitgliedschaft abläuft.',
        );
      case 'paused':
        return _text(
          'Your membership is paused. You cannot purchase another membership while it is paused.',
          'Ihre Mitgliedschaft ist pausiert. Währenddessen können Sie keine weitere Mitgliedschaft erwerben.',
        );
      case 'cancelled':
        return _text(
          'Your membership has been cancelled. You cannot purchase another membership at this time.',
          'Ihre Mitgliedschaft wurde gekündigt. Derzeit können Sie keine weitere Mitgliedschaft erwerben.',
        );
      case 'inactive':
      case 'expired':
        return null;
      default:
        return _text(
          'Your membership status could not be verified. Please refresh your membership details before purchasing another plan.',
          'Ihr Mitgliedschaftsstatus konnte nicht bestätigt werden. Bitte aktualisieren Sie Ihre Mitgliedschaftsdaten, bevor Sie einen weiteren Plan erwerben.',
        );
    }
  }

  String _membershipStatusLabel() {
    switch (_membershipStatus) {
      case 'active':
        return _text('Active membership', 'Aktive Mitgliedschaft');
      case 'inactive':
        return _text('Credit used', 'Guthaben aufgebraucht');
      case 'paused':
        return _text('Paused', 'Pausiert');
      case 'cancelled':
        return _text('Cancelled', 'Gekündigt');
      case 'expired':
        return _text('Expired', 'Abgelaufen');
      default:
        return _text(
          'Membership status unavailable',
          'Mitgliedschaftsstatus nicht verfügbar',
        );
    }
  }

  String _membershipStatusDescription() {
    switch (_membershipStatus) {
      case 'active':
        return _text(
          'Your membership is active. You can use your available shopping credit at checkout. Another membership can be purchased after the credit is fully used or the membership expires.',
          'Ihre Mitgliedschaft ist aktiv. Sie können Ihr verfügbares Einkaufsguthaben beim Checkout verwenden. Eine weitere Mitgliedschaft kann erworben werden, sobald das Guthaben vollständig aufgebraucht ist oder die Mitgliedschaft abläuft.',
        );
      case 'inactive':
        return _text(
          'Your shopping credit has been fully used. You can purchase a new membership.',
          'Ihr Einkaufsguthaben wurde vollständig aufgebraucht. Sie können eine neue Mitgliedschaft erwerben.',
        );
      case 'paused':
        return _text(
          'Your membership is paused. Another membership cannot be purchased while it remains paused.',
          'Ihre Mitgliedschaft ist pausiert. Solange sie pausiert ist, kann keine weitere Mitgliedschaft erworben werden.',
        );
      case 'cancelled':
        return _text(
          'This membership has been cancelled. Contact support if you need help with your membership.',
          'Diese Mitgliedschaft wurde gekündigt. Wenn Sie Hilfe benötigen, wenden Sie sich bitte an den Support.',
        );
      case 'expired':
        return _text(
          'Your membership has expired. You can choose and purchase a new membership.',
          'Ihre Mitgliedschaft ist abgelaufen. Sie können eine neue Mitgliedschaft auswählen und erwerben.',
        );
      default:
        return _text(
          'Your membership is on record, but its current status could not be identified. Please refresh your membership details.',
          'Ihre Mitgliedschaft ist gespeichert, ihr aktueller Status konnte jedoch nicht ermittelt werden. Bitte aktualisieren Sie Ihre Mitgliedschaftsdaten.',
        );
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
        title: _text('Join Ayubo Family', 'Ayubo Family beitreten'),
        message: _text(
          'Sign in or create an account to join the ${_plan['name']} membership plan.',
          'Melden Sie sich an oder erstellen Sie ein Konto, um dem Mitgliedschaftsplan ${_plan['name']} beizutreten.',
        ),
      );

      if (user == null || !mounted) return;
    }

    setState(() => _joining = true);

    try {
      final planId = (_plan['id'] as num?)?.toInt();
      final variantId = (_plan['variant_id'] as num?)?.toInt();

      if (planId != null) {
        await ApiService.instance.purchaseMembership(planId);
      } else if (variantId != null) {
        await ApiService.instance.addToCart(variantId, 1);
      } else {
        _snack(
          _text(
            'This plan is not available for purchase online.',
            'Dieser Plan ist derzeit nicht online erhältlich.',
          ),
        );
        return;
      }

      if (!mounted) return;

      CartState.instance.refresh();

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _text(
                '"${_plan['name']}" added to your cart.',
                '"${_plan['name']}" wurde Ihrem Warenkorb hinzugefügt.',
              ),
            ),
            action: SnackBarAction(
              label: _text('View cart', 'Warenkorb ansehen'),
              textColor: Theme.of(context).colorScheme.secondary,
              onPressed: () {
                if (mounted) {
                  AppBottomBar.open(context, 3, widget.user);
                }
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

      if (e.statusCode != 401) {
        _snack(e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  void dispose() {
    _loadRequestId++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan;
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    // Customer API supplies localized top-level values.
    // German is the backend fallback when a translation is missing.
    final planName = (p['name'] as String?)?.trim().isNotEmpty == true
        ? (p['name'] as String).trim()
        : _text('Membership Plan', 'Mitgliedschaftsplan');

    final tagline = (p['description'] as String?)?.trim();

    final rawBenefits = p['benefits'] as List<dynamic>? ?? const [];
    final benefits = rawBenefits.whereType<Map<String, dynamic>>().toList();

    final blocked = _membershipPurchaseBlockedMessage();
    final priceCents = (p['price_cents'] as num?)?.toInt();

    final price = priceCents != null
        ? formatCents(priceCents)
        : _text('Price unavailable', 'Preis nicht verfügbar');

    final membershipStatusLabel = widget.membership == null
        ? null
        : _membershipStatusLabel();

    final membershipStatusDescription = widget.membership == null
        ? null
        : _membershipStatusDescription();

    return Scaffold(
      appBar: AppHeader(
        title: planName,
        subtitle: _text('Membership Tier', 'Mitgliedschaftsstufe'),
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
                  planName,
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
            _text('incl. VAT', 'inkl. MwSt.'),
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
            _text('What you get', 'Ihre Vorteile'),
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
                      _text(
                        'No benefits are listed for this membership yet.',
                        'Für diese Mitgliedschaft sind noch keine Vorteile aufgeführt.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final benefit in benefits)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: BenefitLine(
                              benefit: benefit,
                              color: widget.accent,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _text(
              'Your membership starts when your order is paid.',
              'Ihre Mitgliedschaft beginnt, sobald Ihre Bestellung bezahlt wurde.',
            ),
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
                  ? _text(
                      'Membership purchase unavailable',
                      'Mitgliedschaft derzeit nicht verfügbar',
                    )
                  : _text('Join for $price', 'Jetzt beitreten für $price'),
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
                _text(
                  'This plan is currently unavailable for purchase.',
                  'Dieser Plan ist derzeit nicht zum Kauf verfügbar.',
                ),
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
