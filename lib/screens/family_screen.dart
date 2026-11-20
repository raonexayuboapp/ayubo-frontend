import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../theme/app_theme.dart';
import '../utils/membership_status.dart';
import '../utils/membership_style.dart';
import '../utils/money.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/benefit_line.dart';
import '../widgets/prompt_dialog.dart';
import 'checkout_screen.dart';
import 'loyalty_screen.dart';
import 'membership_plan_screen.dart';
import 'vouchers_screen.dart';

typedef PlanData = Map<String, dynamic>;
typedef MembershipData = Map<String, dynamic>;
typedef VoucherAmountData = Map<String, dynamic>;

class FamilyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialSection;

  const FamilyScreen({super.key, required this.user, this.initialSection = 0});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  static const _previewCount = 3;

  late Map<String, dynamic> _user = widget.user;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _plansKey = GlobalKey();
  final GlobalKey _vouchersKey = GlobalKey();

  Map<String, dynamic>? _data;
  List<VoucherAmountData> _voucherAmounts = [];

  bool _loading = true;
  String? _error;

  // Tracks the language used for the most recently requested data.
  String? _loadedLanguage;

  // Prevents the initial-section scroll from running more than once.
  bool _initialScrollHandled = false;

  List<PlanData> get _plans =>
      ((_data?['plans'] as List<dynamic>?) ?? const []).cast<PlanData>();

  MembershipData? get _membership => _data?['membership'] as MembershipData?;

  String? get _membershipStatus =>
      (_membership?['status'] ?? '').toString().trim().toLowerCase();

  bool get _hasMembership => _membership != null;

  bool get _isActiveMember => _membershipStatus == 'active';

  bool get _canReactivateMembership => _membershipStatus == 'inactive';

  String _membershipStatusLabel(bool isDe) {
    switch (_membershipStatus) {
      case 'active':
        return isDe ? 'AKTIV' : 'ACTIVE';
      case 'inactive':
        return isDe ? 'INAKTIV' : 'INACTIVE';
      case 'paused':
        return isDe ? 'PAUSIERT' : 'PAUSED';
      case 'cancelled':
        return isDe ? 'GEKÜNDIGT' : 'CANCELLED';
      case 'expired':
        return isDe ? 'ABGELAUFEN' : 'EXPIRED';
      default:
        return isDe ? 'STATUS PRÜFEN' : 'STATUS UNAVAILABLE';
    }
  }

  String _membershipStatusDescription(bool isDe) {
    switch (_membershipStatus) {
      case 'active':
        return isDe
            ? 'Ihre Mitgliedschaft ist aktiv. Ihr verfügbares Einkaufsguthaben kann beim Checkout verwendet werden.'
            : 'Your membership is active. Available shopping credit can be used at checkout.';
      case 'inactive':
        return isDe
            ? 'Ihr Einkaufsguthaben ist aufgebraucht. Sie können Ihre bisherige Mitgliedschaft erneut erwerben.'
            : 'Your shopping credit has been exhausted. You can purchase your previous membership plan again.';
      case 'paused':
        return isDe
            ? 'Ihre Mitgliedschaft ist pausiert. Währenddessen können Sie keine neue Mitgliedschaft erwerben.'
            : 'Your membership is paused. You cannot purchase another membership while it is paused.';
      case 'cancelled':
        return isDe
            ? 'Ihre Mitgliedschaft wurde gekündigt. Für weitere Hilfe wenden Sie sich bitte an den Support.'
            : 'Your membership has been cancelled. Please contact support if you need assistance.';
      case 'expired':
        return isDe
            ? 'Ihre Mitgliedschaft ist abgelaufen. Sie können eine neue Mitgliedschaft wählen.'
            : 'Your membership has expired. You can choose a new membership.';
      default:
        return isDe
            ? 'Der Mitgliedschaftsstatus konnte nicht bestätigt werden.'
            : 'Your membership status could not be verified.';
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final language = Localizations.localeOf(context).languageCode.toLowerCase();

    if (_loadedLanguage != language) {
      _loadedLanguage = language;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        await _load();

        if (!mounted || _initialScrollHandled) return;

        _initialScrollHandled = true;

        if (widget.initialSection == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollTo(_vouchersKey);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;

    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.instance.membershipPlans().catchError(
          (_) => <String, dynamic>{'plans': <dynamic>[], 'membership': null},
        ),
        ApiService.instance.giftVoucherAmounts().catchError(
          (_) => <VoucherAmountData>[],
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _voucherAmounts = (results[1] as List<dynamic>)
            .cast<VoucherAmountData>();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;

        if (_data == null) {
          _error = e.statusCode == 401
              ? 'Unable to load Ayubo Family data.'
              : e.message;
        }
      });

      if (_data != null && e.statusCode != 401) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to connect. Swipe down to retry.';
      });
    }
  }

  Future<bool> _ensureSignedIn(String title, String message) async {
    if (await ApiService.instance.hasToken()) return true;

    if (!mounted) return false;

    final user = await showAuthPrompt(context, title: title, message: message);

    if (user == null || !mounted) return false;

    setState(() => _user = user);

    return true;
  }

  Future<void> _openPlan(PlanData plan, Color accent) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MembershipPlanScreen(
          plan: plan,
          membership: _membership,
          user: _user,
          accent: accent,
        ),
      ),
    );

    if (mounted) {
      _load();
    }
  }

  Future<void> _quickJoin(PlanData plan) async {
    final blocked = joinBlockedMessage(_membership);

    if (blocked != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }

    final planId = (plan['id'] as num?)?.toInt();
    final variantId = (plan['variant_id'] as num?)?.toInt();

    if (planId == null && variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This membership plan cannot be ordered online.'),
        ),
      );
      return;
    }

    if (!await _ensureSignedIn(
      'Join Ayubo Family',
      'Sign in or create an account to join the ${plan['name']} membership plan.',
    )) {
      return;
    }

    try {
      if (planId != null) {
        await ApiService.instance.purchaseMembership(planId);
      } else {
        await ApiService.instance.addToCart(variantId!, 1);
      }

      if (!mounted) return;

      CartState.instance.refresh();

      _showCartSnack(
        '"${plan['name']}" added to your cart.',
        'View Cart',
        () => AppBottomBar.open(context, 3, _user),
      );
    } on ApiException catch (e) {
      if (mounted && e.statusCode == 409) {
        _load();
        CartState.instance.refresh();
      }

      if (mounted && e.statusCode != 401) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Adds the customer's previous membership plan to the cart.
  ///
  /// This does not immediately reactivate the membership.
  /// Activation and shopping-credit issuance remain controlled by
  /// the backend after successful payment.
  Future<void> _reactivateMembership() async {
    final membership = _membership;

    if (membership == null || !_canReactivateMembership) return;

    final nestedPlan = membership['plan'] as Map<String, dynamic>?;

    final planId =
        (membership['plan_id'] as num?)?.toInt() ??
        (nestedPlan?['id'] as num?)?.toInt();

    if (planId == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your previous membership plan could not be identified. Please contact support.',
          ),
        ),
      );

      return;
    }

    PlanData? previousPlan;

    for (final candidate in _plans) {
      final candidateId = (candidate['id'] as num?)?.toInt();

      if (candidateId == planId) {
        previousPlan = candidate;
        break;
      }
    }

    final planToPurchase =
        previousPlan ??
        <String, dynamic>{
          'id': planId,
          'name':
              membership['plan_name'] ?? nestedPlan?['name'] ?? 'Membership',
        };

    await _quickJoin(planToPurchase);
  }

  Future<void> _buyVoucher(VoucherAmountData amount, int quantity) async {
    final locale = Localizations.localeOf(context).languageCode;
    final priceCents = (amount['price_cents'] as num?)?.toInt();
    final variantId = (amount['variant_id'] as num?)?.toInt();
    final name = amount['name'] as String? ?? 'Gift voucher';

    if (variantId == null || priceCents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher denomination is currently unavailable.'),
        ),
      );
      return;
    }

    if (!await _ensureSignedIn(
      'Purchase Gift Voucher',
      'Sign in or create an account to purchase the $name.',
    )) {
      return;
    }

    try {
      await ApiService.instance.addGiftVouchersToCart(variantId, quantity);

      CartState.instance.refresh();

      if (!mounted) return;

      _showCartSnack(
        'Added $quantity × ${formatCents(priceCents, locale)} voucher.',
        'Checkout',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CheckoutScreen(user: _user)),
        ),
      );
    } on ApiException catch (e) {
      if (mounted && e.statusCode != 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.fieldErrors.isNotEmpty
                  ? e.fieldErrors.values.join('\n')
                  : e.message,
            ),
          ),
        );
      }
    }
  }

  void _showCartSnack(String text, String actionLabel, VoidCallback onAction) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Expanded(
                child: Text(text, style: const TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: AppTheme.brandGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showBuyVoucherSheet(VoucherAmountData amount) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoucherPurchaseSheet(
        amount: amount,
        onConfirm: (quantity) {
          Navigator.pop(ctx);
          _buyVoucher(amount, quantity);
        },
      ),
    );
  }

  Future<void> _openMyVouchers() async {
    if (!await _ensureSignedIn(
      'My Vouchers & Credit',
      'Sign in to view your vouchers and shopping credit balance.',
    )) {
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VouchersScreen()),
    );

    if (mounted) {
      _load();
    }
  }

  Future<void> _claimVoucherCode() async {
    if (!await _ensureSignedIn(
      'Claim Gift Voucher',
      'Sign in to add a voucher to your wallet.',
    )) {
      return;
    }

    if (!mounted) return;

    final result = await showPrompt(
      context,
      title: 'Claim a Gift Voucher',
      message: 'Enter your voucher code to credit the balance to your wallet.',
      confirmLabel: 'Claim Voucher',
      fields: const [
        PromptField(
          key: 'code',
          label: 'Voucher code',
          required: true,
          maxLength: 40,
        ),
      ],
    );

    if (result == null || !mounted) return;

    try {
      final claimed = await ApiService.instance.claimVoucher(result['code']!);

      if (!mounted) return;

      final balance = (claimed['balance_cents'] as num?)?.toInt() ?? 0;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Voucher claimed! Wallet balance: ${formatCents(balance)}.',
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.fieldErrors.isNotEmpty
                  ? e.fieldErrors.values.join('\n')
                  : e.message,
            ),
          ),
        );
      }
    }
  }

  Future<void> _openLoyalty() async {
    if (!await _ensureSignedIn(
      'Ayubo Loyalty Rewards',
      'Sign in to view your loyalty points balance and reward tiers.',
    )) {
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
    );
  }

  // ===========================================================================
  // 1. HERO / MEMBER STATUS CARD
  // ===========================================================================

  Widget _buildHeroSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    if (_hasMembership) {
      final membershipPlan =
          _membership!['plan'] as Map<String, dynamic>? ?? {};

      // Prefer the localized plan name from the customer plans response.
      // The membership endpoint's plan_name is retained as a fallback.
      final membershipPlanId =
          (_membership!['plan_id'] as num?)?.toInt() ??
          (membershipPlan['id'] as num?)?.toInt();

      String? localizedPlanName;

      for (final candidate in _plans) {
        final candidateId = (candidate['id'] as num?)?.toInt();

        if (candidateId == membershipPlanId) {
          localizedPlanName = (candidate['name'] as String?)?.trim();
          break;
        }
      }

      final planName =
          (localizedPlanName != null && localizedPlanName.isNotEmpty)
          ? localizedPlanName
          : (_membership!['plan_name'] as String?) ??
                (membershipPlan['name'] as String?) ??
                'Ayubo Family Member';

      final cardNo =
          (_membership!['member_number'] as String?) ??
          (_membership!['card_number'] as String?) ??
          'AYU-MEMBER';

      final creditCents = (_membership!['credit_cents'] as num?)?.toInt() ?? 0;

      final discount =
          (_membership!['discount_percent'] as num?)?.toDouble() ??
          (membershipPlan['discount_percent'] as num?)?.toDouble() ??
          0.0;

      // A membership discount is only displayed while the membership is active.
      // Never use the membership status as a fallback discount value.
      final displayDiscount = _isActiveMember ? discount : 0.0;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.brandGold.withValues(alpha: 0.6),
            width: 1.4,
          ),
          image: const DecorationImage(
            image: AssetImage('assets/images/tea plantation.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGreen.withValues(alpha: 0.94),
                const Color(0xFF0E291E).withValues(alpha: 0.90),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppTheme.brandGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      planName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.brandGold),
                    ),
                    child: Text(
                      _membershipStatusLabel(isDe),
                      style: const TextStyle(
                        color: AppTheme.brandGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _membershipStatusDescription(isDe),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDe ? 'Einkaufsguthaben' : 'Shopping Credit',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          formatCents(creditCents),
                          style: const TextStyle(
                            color: AppTheme.brandGold,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 34, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.storeDiscount ?? 'Member Discount',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          displayDiscount > 0
                              ? '${displayDiscount.toStringAsFixed(0)}% OFF'
                              : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Card #$cardNo',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  InkWell(
                    onTap: _openMyVouchers,
                    child: Row(
                      children: [
                        Text(
                          isDe ? 'Wallet öffnen' : 'Open Wallet',
                          style: const TextStyle(
                            color: AppTheme.brandGold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppTheme.brandGold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Only an inactive membership can be purchased again here.
              if (_canReactivateMembership) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _reactivateMembership,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      isDe
                          ? 'Mitgliedschaft reaktivieren'
                          : 'Reactivate Membership',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandGold,
                      foregroundColor: const Color(0xFF1B4332),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Guest / Non-Member Hero Banner with Ceylon Plantation Backdrop.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/tea plantation.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.92),
              const Color(0xFF0E291E).withValues(alpha: 0.86),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/Ayubo_logo.png',
                  height: 28,
                  width: 28,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDe ? 'EINKAUFSGUTHABEN' : 'SHOPPING CREDIT',
                    style: const TextStyle(
                      color: AppTheme.brandGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.joinAyuboFamily ?? 'Ayubo Family & Gifting',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDe
                  ? 'Mitgliedschaftspläne bieten Einkaufsguthaben und exklusive Vorteile auf reine Ceylon-Bio-Produkte.'
                  : 'Membership plans include shopping credit and exclusive benefits on pure Ceylon organics.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _scrollTo(_plansKey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandGold,
                      foregroundColor: const Color(0xFF1B4332),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isDe ? 'Pläne entdecken' : 'Explore Plans',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _scrollTo(_vouchersKey),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.brandGold),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isDe ? 'Gutscheine' : 'Gift Vouchers',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. QUICK WALLET & LOYALTY STRIP
  // ===========================================================================

  Widget _buildQuickActionStrip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    Widget chip(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardSubtleColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: AppTheme.brandGoldDark),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          chip(
            Icons.account_balance_wallet_outlined,
            l10n?.myVouchers ?? 'My Wallet',
            _openMyVouchers,
          ),
          const SizedBox(width: 8),
          chip(
            Icons.qr_code_rounded,
            isDe ? 'Code einlösen' : 'Claim Code',
            _claimVoucherCode,
          ),
          const SizedBox(width: 8),
          chip(
            Icons.stars_rounded,
            isDe ? 'Treuepunkte' : 'Loyalty Points',
            _openLoyalty,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. MEMBERSHIP PLANS SECTION
  // ===========================================================================

  String _planAsset(int rank) => switch (rank % 3) {
    0 => 'assets/images/cinnamon plantation.jpg',
    1 => 'assets/images/pepper plantation.jpg',
    _ => 'assets/images/tea plantation.jpg',
  };

  Widget _buildPlansSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      key: _plansKey,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_membership_rounded,
                size: 18,
                color: AppTheme.brandGoldDark,
              ),
              const SizedBox(width: 8),
              Text(
                isDe ? 'Mitgliedschaftspläne' : 'Membership Plans',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_plans.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Center(
                child: Text(
                  isDe
                      ? 'Derzeit sind keine Pläne verfügbar.'
                      : 'No membership plans available currently.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < _plans.length; i++)
              _buildPlanCard(context, _plans[i], i, tierColor(i)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    PlanData plan,
    int rank,
    Color accent,
  ) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final benefits = (plan['benefits'] as List<dynamic>? ?? const []);

    final priceCents = (plan['price_cents'] as num?)?.toInt();

    final creditCents = (plan['credit_cents'] as num?)?.toInt();

    final discountPercent =
        (plan['discount_percent'] as num?)?.toDouble() ??
        (plan['discount_percentage'] as num?)?.toDouble();

    final durationMonths = (plan['duration_months'] as num?)?.toInt();

    final planId = plan['id'];

    // These fields are localized by the backend customer API.
    // The backend returns German as the fallback when a translation is absent.
    final planName = (plan['name'] as String?)?.trim();
    final planDescription = (plan['description'] as String?)?.trim();

    final isCurrent =
        _isActiveMember &&
        ((_membership!['plan_id'] != null &&
                _membership!['plan_id'] == planId) ||
            ((_membership!['plan'] as Map<String, dynamic>?)?['id'] == planId));

    final purchaseBlocked = membershipBlocksJoining(_membership);

    final variantId = (plan['variant_id'] as num?)?.toInt();

    final canPurchasePlan =
        priceCents != null && (planId is num || variantId != null);

    final durationText = durationMonths != null && durationMonths > 0
        ? (isDe ? '$durationMonths Monate' : '$durationMonths Months')
        : (isDe ? 'Jahresplan' : 'Annual Plan');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? AppTheme.brandGold
              : AppTheme.brandGold.withValues(alpha: 0.35),
          width: isCurrent ? 1.8 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Image Header Banner.
          Container(
            height: 76,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_planAsset(rank)),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          planName?.isNotEmpty == true ? planName! : 'Plan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          durationText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n?.currentPlan ?? 'ACTIVE',
                        style: const TextStyle(
                          color: Color(0xFF1B4332),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (priceCents != null)
                    Text(
                      formatCents(priceCents),
                      style: const TextStyle(
                        color: AppTheme.brandGold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Plan details and benefits.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (creditCents != null && creditCents > 0)
                      _badge(
                        Icons.account_balance_wallet_outlined,
                        '${isDe ? 'Einkaufsguthaben' : 'Shopping Credit'} · ${formatCents(creditCents)}',
                        AppTheme.brandGold.withValues(alpha: 0.18),
                        AppTheme.brandGoldDark,
                      ),
                    if (discountPercent != null && discountPercent > 0)
                      _badge(
                        Icons.sell_outlined,
                        '${discountPercent.toStringAsFixed(0)}% OFF',
                        AppTheme.primaryGreen.withValues(alpha: 0.12),
                        isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
                      ),
                  ],
                ),

                // Localized plan description.
                if (planDescription != null && planDescription.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    planDescription,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                for (final b in benefits.take(_previewCount))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: BenefitLine(
                      benefit: b is Map<String, dynamic>
                          ? b
                          : {'kind': 'perk', 'description': b.toString()},
                      color: accent,
                    ),
                  ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openPlan(plan, accent),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppTheme.brandGold.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          l10n?.viewDetails ?? 'Details',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            isCurrent || purchaseBlocked || !canPurchasePlan
                            ? null
                            : () => _quickJoin(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.brandGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: Text(
                          isCurrent
                              ? (l10n?.currentPlan ?? 'Active')
                              : purchaseBlocked
                              ? (isDe ? 'Nicht verfügbar' : 'Unavailable')
                              : (l10n?.joinNow ?? 'Join Plan'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. GIFT VOUCHERS SECTION
  // ===========================================================================

  Widget _buildVouchersSection(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      key: _vouchersKey,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                size: 18,
                color: AppTheme.brandGoldDark,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.giftVouchers ?? 'Gift Vouchers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Gifting Showcase Card with Asset Image.
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132018) : const Color(0xFFFBF8F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.brandGold.withValues(alpha: 0.4),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Image.asset(
                    'assets/images/harmonie_set_for_her.webp',
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.giftVoucherPromoTitle ??
                              'The Gift of Ceylon Wellness',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDe
                              ? 'Sofortige E-Mail-Lieferung · 0% MwSt. · Kein Verfall'
                              : 'Instant email delivery · 0% VAT · Never expires',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_voucherAmounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Center(
                child: Text(
                  isDe
                      ? 'Keine Gutscheinbeträge verfügbar.'
                      : 'No voucher denominations available.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _voucherAmounts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) =>
                  _buildVoucherCard(context, _voucherAmounts[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(BuildContext context, VoucherAmountData amount) {
    final locale = Localizations.localeOf(context).languageCode;
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);

    final priceCents = (amount['price_cents'] as num?)?.toInt();

    final name = amount['name'] as String? ?? 'Gift Voucher';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1B1C20), const Color(0xFF121316)]
              : [Colors.white, const Color(0xFFFBF8F1)],
        ),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: isDark ? 0.45 : 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGold.withValues(alpha: isDark ? 0.10 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBuyVoucherSheet(amount),
          child: Stack(
            children: [
              // Subtle Decorative Gold Watermark.
              Positioned(
                right: -14,
                top: -14,
                child: Icon(
                  Icons.spa_rounded,
                  size: 76,
                  color: AppTheme.brandGold.withValues(
                    alpha: isDark ? 0.07 : 0.09,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.brandGold.withValues(alpha: 0.25),
                                AppTheme.brandGoldDark.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.brandGold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            size: 16,
                            color: AppTheme.brandGoldDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandGold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GIFT CARD',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.brandGoldDark,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    Text(
                      priceCents != null
                          ? formatCents(priceCents, locale)
                          : '—',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppTheme.brandGold
                            : AppTheme.brandGoldDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showBuyVoucherSheet(amount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandGold,
                          foregroundColor: const Color(0xFF141417),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          l10n?.buyVoucher ?? 'Buy Voucher',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    Widget body;

    if (_loading && _data == null) {
      body = const Center(
        child: CircularProgressIndicator(
          color: AppTheme.brandGold,
          strokeWidth: 2.5,
        ),
      );
    } else if (_error != null && _data == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.spa_rounded,
                size: 48,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.brandGold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brandGold,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeroSection(context),
            _buildQuickActionStrip(context),
            _buildPlansSection(context),
            _buildVouchersSection(context),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.familyTitle ?? 'Ayubo Family',
        subtitle: isDe ? 'Privilegien & Geschenke' : 'Privileges & Gifting',
        user: _user,
        showBackButton: Navigator.canPop(context),
        onProfileClosed: _load,
      ),
      body: body,
      bottomNavigationBar: AppBottomBar(currentIndex: 2, user: _user),
    );
  }
}

// =============================================================================
// MODAL SHEET: VOUCHER QUANTITY & PURCHASE
// =============================================================================

class _VoucherPurchaseSheet extends StatefulWidget {
  final VoucherAmountData amount;
  final ValueChanged<int> onConfirm;

  const _VoucherPurchaseSheet({required this.amount, required this.onConfirm});

  @override
  State<_VoucherPurchaseSheet> createState() => _VoucherPurchaseSheetState();
}

class _VoucherPurchaseSheetState extends State<_VoucherPurchaseSheet> {
  static const _max = 10;

  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final priceCents = (widget.amount['price_cents'] as num?)?.toInt() ?? 0;

    final name = widget.amount['name'] as String? ?? 'Gift Voucher';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: AppTheme.brandGold.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${formatCents(priceCents, locale)} · ${isDe ? 'Sofort per E-Mail' : 'Instant Email Delivery'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  isDe ? 'Menge' : 'Quantity',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _quantity < _max
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onConfirm(_quantity),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.brandGold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '${isDe ? 'In den Warenkorb' : 'Add to Cart'} · ${formatCents(priceCents * _quantity, locale)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
