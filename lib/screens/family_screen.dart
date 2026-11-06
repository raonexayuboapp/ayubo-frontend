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
  final int initialSection; // 0 = Memberships, 1 = Gift Vouchers

  const FamilyScreen({
    super.key,
    required this.user,
    this.initialSection = 0,
  });

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  static const _previewCount = 4;

  late Map<String, dynamic> _user = widget.user;
  late int _selectedSection = widget.initialSection;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _plansKey = GlobalKey();

  Map<String, dynamic>? _data;
  List<VoucherAmountData> _voucherAmounts = [];

  bool _loading = true;
  String? _error;

  List<PlanData> get _plans =>
      ((_data?['plans'] as List<dynamic>?) ?? const []).cast<PlanData>();

  MembershipData? get _membership =>
      _data?['membership'] as MembershipData?;

  bool get _isMember =>
      _membership != null && _membership!['status'] == 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plansFuture = ApiService.instance.membershipPlans();
      final vouchersFuture = ApiService.instance.giftVoucherAmounts();

      final results = await Future.wait([
        plansFuture.catchError((_) => <String, dynamic>{'plans': <dynamic>[], 'membership': null}),
        vouchersFuture.catchError((_) => <VoucherAmountData>[]),
      ]);

      if (!mounted) return;

      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _voucherAmounts = (results[1] as List<dynamic>).cast<VoucherAmountData>();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (_data == null) {
          _error = e.statusCode == 401 ? 'Unable to load Ayubo Family data.' : e.message;
        }
      });

      if (_data != null && e.statusCode != 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to connect. Please swipe down to retry.';
      });
    }
  }

  void _scrollToPlans() {
    final ctx = _plansKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // ===========================================================================
  // ACTIONS: MEMBERSHIP
  // ===========================================================================
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }

    final variantId = (plan['variant_id'] as num?)?.toInt();
    if (variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This membership plan cannot be ordered online.')),
      );
      return;
    }

    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'Join Ayubo Family',
        message: 'Sign in or create an account to join the ${plan['name']} membership plan.',
      );
      if (user == null || !mounted) return;
      setState(() => _user = user);
    }

    try {
      await ApiService.instance.addToCart(variantId, 1);
      if (!mounted) return;

      CartState.instance.refresh();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('"${plan['name']}" added to your cart.'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: AppTheme.brandGold,
              onPressed: () {
                if (mounted) AppBottomBar.open(context, 3, _user);
              },
            ),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode != 401) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // ===========================================================================
  // ACTIONS: GIFT VOUCHERS
  // ===========================================================================
  Future<void> _buyVoucher(VoucherAmountData amount, int quantity) async {
    final priceCents = (amount['price_cents'] as num?)?.toInt();
    final variantId = (amount['variant_id'] as num?)?.toInt();
    final name = amount['name'] as String? ?? 'Gift voucher';

    if (variantId == null || priceCents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voucher denomination is currently unavailable.')),
      );
      return;
    }

    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'Purchase Gift Voucher',
        message: 'Sign in or create an account to purchase the $name.',
      );
      if (user == null || !mounted) return;
      setState(() => _user = user);
    }

    try {
      await ApiService.instance.addGiftVouchersToCart(variantId, quantity);
      CartState.instance.refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Added to your cart: $quantity × ${formatCents(priceCents)} gift voucher.',
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Checkout',
              textColor: AppTheme.brandGold,
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(user: _user),
                  ),
                );
              },
            ),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode != 401) {
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
    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'My Vouchers & Credit',
        message: 'Sign in or create an account to view your vouchers and shopping credit balance.',
      );
      if (user == null || !mounted) return;
      setState(() => _user = user);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VouchersScreen()),
    );
  }

  Future<void> _claimVoucherCode() async {
    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'Claim Gift Voucher',
        message: 'Sign in or create an account to add a voucher to your wallet.',
      );
      if (user == null || !mounted) return;
      setState(() => _user = user);
    }

    if (!mounted) return;

    final result = await showPrompt(
      context,
      title: 'Claim a Gift Voucher',
      message: 'Enter the voucher code from your email or gift card. The balance will be credited to your account wallet.',
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
            content: Text('Voucher claimed successfully! Wallet balance: ${formatCents(balance)}.'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\n') : e.message,
          ),
        ),
      );
    }
  }

  Future<void> _openLoyalty() async {
    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'Ayubo Loyalty Rewards',
        message: 'Sign in or create an account to view your loyalty points balance and reward tiers.',
      );
      if (user == null || !mounted) return;
      setState(() => _user = user);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
    );
  }

  // ===========================================================================
  // MOBILE-FIRST COMPACT HEADER
  // ===========================================================================
  Widget _buildScreenHeader(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : const Color(0xFFF2F6F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: isDark ? 0.35 : 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGold.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.brandGold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: AppTheme.brandGoldDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDe ? 'PRIVILEGIEN & GESCHENKE' : 'PRIVILEGES & GIFTING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.familyTitle ?? 'Ayubo Family',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDe
                      ? '100% Guthaben-Rückerstattung & edle Wellness-Geschenke'
                      : '100% shopping credit back & mindful wellness gifting',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary(context),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION SWITCHER SEGMENT (PILL STYLE)
  // ===========================================================================
  Widget _buildSegmentSwitcher(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardSubtleColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Tab 0: Memberships
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedSection != 0) setState(() => _selectedSection = 0);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSection == 0
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedSection == 0
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_membership_rounded,
                      size: 16,
                      color: _selectedSection == 0
                          ? AppTheme.brandGold
                          : AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n?.memberships ?? 'Memberships',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _selectedSection == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _selectedSection == 0
                            ? Colors.white
                            : AppTheme.textSecondary(context),
                      ),
                    ),
                    if (_plans.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedSection == 0
                              ? AppTheme.brandGold.withValues(alpha: 0.25)
                              : AppTheme.borderColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_plans.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _selectedSection == 0
                                ? AppTheme.brandGold
                                : AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Tab 1: Gift Vouchers
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedSection != 1) setState(() => _selectedSection = 1);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSection == 1
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedSection == 1
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: 16,
                      color: _selectedSection == 1
                          ? AppTheme.brandGold
                          : AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n?.giftVouchers ?? 'Gift Vouchers',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _selectedSection == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _selectedSection == 1
                            ? Colors.white
                            : AppTheme.textSecondary(context),
                      ),
                    ),
                    if (_voucherAmounts.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedSection == 1
                              ? AppTheme.brandGold.withValues(alpha: 0.25)
                              : AppTheme.borderColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_voucherAmounts.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _selectedSection == 1
                                ? AppTheme.brandGold
                                : AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PILLAR 1: MEMBERSHIPS TAB CONTENT
  // ===========================================================================
  Widget _buildMembershipsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Membership Overview (Top: Member card or Guest Invitation)
        _buildMembershipOverview(context),

        // 2. Core Benefits (4 Compact Cards)
        _buildCoreBenefits(context),

        // 3. Membership Plans Section
        _buildPlansSection(context),

        // 4. Membership Credit & Loyalty Cards
        _buildCreditAndLoyaltySection(context),

        // 5. Clean FAQ / Philosophy Accordion
        _buildFaqSection(context),
      ],
    );
  }

  // ===========================================================================
  // A. MEMBERSHIP OVERVIEW CARD
  // ===========================================================================
  Widget _buildMembershipOverview(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    if (_isMember) {
      final plan = _membership!['plan'] as Map<String, dynamic>? ?? {};
      final planName = (_membership!['plan_name'] as String?) ??
          (plan['name'] as String?) ??
          'Ayubo Family Member';
      final cardNo = (_membership!['member_number'] as String?) ??
          (_membership!['card_number'] as String?) ??
          'AYU-MEMBER';
      final creditCents = (_membership!['credit_cents'] as num?)?.toInt() ?? 0;
      final discountPercent = (_membership!['discount_percent'] as num?)?.toDouble() ??
          (plan['discount_percent'] as num?)?.toDouble() ??
          0.0;
      final validUntil = (_membership!['valid_until'] as String?) ??
          (_membership!['expires_at'] as String?);

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF132018) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.brandGold.withValues(alpha: 0.5),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandGold.withValues(alpha: isDark ? 0.12 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppTheme.brandGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      planName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.brandGold.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      l10n?.activeMember ?? 'ACTIVE',
                      style: const TextStyle(
                        color: AppTheme.brandGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metrics Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  // Credit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDe ? 'Mitgliedsguthaben' : 'Membership Credit',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCents(creditCents),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.brandGoldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppTheme.borderColor(context),
                  ),
                  const SizedBox(width: 16),
                  // Store Discount
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.storeDiscount ?? 'Store Discount',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          discountPercent > 0
                              ? '${discountPercent.toStringAsFixed(0)}% OFF'
                              : 'Active',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    validUntil != null && validUntil.isNotEmpty
                        ? (isDe ? 'Gültig bis $validUntil' : 'Valid until $validUntil')
                        : 'Card #$cardNo',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  InkWell(
                    onTap: _openMyVouchers,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isDe ? 'Guthaben ansehen' : 'View Wallet',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brandGoldDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.brandGoldDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Guest / Non-member Invitation Card
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : const Color(0xFFFBF8F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGold.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded, color: AppTheme.brandGoldDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.joinAyuboFamily ?? 'Join Ayubo Family',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      isDe
                          ? '100% Guthaben-Rückerstattung auf jeden Euro'
                          : '100% Credit Back on every euro invested',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brandGoldDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isDe
                ? 'Werden Sie Teil unserer exklusiven Gemeinschaft. Ihr Mitgliedsbeitrag wird sofort zu 100% als Einkaufsguthaben gutgeschrieben – plus bis zu 20% Dauerrabatt.'
                : 'Become part of our exclusive wellness circle. 100% of your membership fee is returned immediately as store credit to spend on pure Ceylon items.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _scrollToPlans,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.brandGold,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                isDe ? 'Mitgliedschaftspläne ansehen' : 'Explore Membership Plans',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // B. CORE BENEFITS GRID (2x2)
  // ===========================================================================
  Widget _buildCoreBenefits(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final benefits = isDe
        ? [
            (
              Icons.account_balance_wallet_outlined,
              '100% Guthaben',
              'Jeder Euro Mitgliedsbeitrag wird sofort als Einkaufsguthaben gutgeschrieben.',
            ),
            (
              Icons.percent_rounded,
              'Mitgliederrabatt',
              'Bis zu 20% Dauerrabatt auf alle reinen Bio-Gewürze, Tees und Kosmetik.',
            ),
            (
              Icons.stars_rounded,
              'Treue-Multiplikator',
              'Sammeln Sie bei jeder Bestellung zusätzliche Treuepunkte.',
            ),
            (
              Icons.eco_outlined,
              'Ernte-Vorzug',
              'Exklusiver Vorab-Zugriff auf frische Ceylon-Zimternten und Raritäten.',
            ),
          ]
        : [
            (
              Icons.account_balance_wallet_outlined,
              '100% Credit Back',
              'Every euro paid returns as instant shopping credit to spend freely.',
            ),
            (
              Icons.percent_rounded,
              'Member Savings',
              'Up to 20% exclusive discount across our complete organic collection.',
            ),
            (
              Icons.stars_rounded,
              'Reward Multiplier',
              'Earn accelerated loyalty points on every purchase you make.',
            ),
            (
              Icons.eco_outlined,
              'Priority Harvest',
              'First reserve access to rare seasonal Ceylon harvests and artisan teas.',
            ),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.memberPrivileges ?? 'Membership Privileges',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              Text(
                '100% VALUE',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.brandGoldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: benefits.map((b) {
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cardSubtleColor(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.borderColor(context),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(b.$1, size: 16, color: AppTheme.brandGoldDark),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.$3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.25,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // C. MEMBERSHIP PLANS SECTION
  // ===========================================================================
  Widget _buildPlansSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      key: _plansKey,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isDe ? 'Verfügbare Mitgliedschaften' : 'Available Membership Plans',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (_plans.isNotEmpty)
                Text(
                  '${_plans.length} ${isDe ? 'Optionen' : 'Plans'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isDe
                ? 'Wählen Sie Ihren gewünschten Plan. 100% des Beitrags erhalten Sie direkt als Guthaben zurück.'
                : 'Select your preferred tier. 100% of the fee is instantly credited to your wallet balance.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),

          if (_plans.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Center(
                child: Text(
                  isDe
                      ? 'Derzeit sind keine Pläne online verfügbar.'
                      : 'No membership plans available online currently.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context)),
                ),
              ),
            )
          else
            for (var i = 0; i < _plans.length; i++)
              _buildPlanCard(context, _plans[i], tierColor(i)),
        ],
      ),
    );
  }

  Widget _buildBenefitLine(dynamic b, Color color) {
    if (b is Map<String, dynamic>) {
      return BenefitLine(benefit: b, color: color);
    }
    return BenefitLine(
      benefit: {'kind': 'perk', 'description': b.toString()},
      color: color,
    );
  }

  Widget _buildPlanCard(BuildContext context, PlanData plan, Color accent) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final benefits = (plan['benefits'] as List<dynamic>? ?? const []);
    final priceCents = (plan['price_cents'] as num?)?.toInt();
    final creditCents = (plan['credit_cents'] as num?)?.toInt() ?? priceCents;
    final discountPercent = (plan['discount_percent'] as num?)?.toDouble() ??
        (plan['discount_percentage'] as num?)?.toDouble();
    final durationMonths = (plan['duration_months'] as num?)?.toInt();
    final planId = plan['id'];

    final isCurrent = _membership != null &&
        ((_membership!['plan_id'] != null && _membership!['plan_id'] == planId) ||
            ((_membership!['plan'] as Map<String, dynamic>?)?['id'] == planId)) &&
        _membership!['status'] == 'active';

    final durationText = durationMonths != null && durationMonths > 0
        ? (isDe ? '$durationMonths Monate' : '$durationMonths Months')
        : (isDe ? 'Jahresmitgliedschaft' : 'Annual Plan');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppTheme.brandGold
              : AppTheme.brandGold.withValues(alpha: isDark ? 0.35 : 0.25),
          width: isCurrent ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.18))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'] as String? ?? 'Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n?.currentPlan ?? 'ACTIVE',
                      style: const TextStyle(
                        color: Color(0xFF1B4332),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (priceCents != null)
                  Text(
                    formatCents(priceCents),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandGoldDark,
                    ),
                  ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlights Badges Row
                Row(
                  children: [
                    if (creditCents != null && creditCents > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.brandGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: AppTheme.brandGoldDark),
                            const SizedBox(width: 4),
                            Text(
                              isDe
                                  ? '100% Guthaben (${formatCents(creditCents)})'
                                  : '100% Credit (${formatCents(creditCents)})',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.brandGoldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (discountPercent != null && discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sell_outlined, size: 12, color: AppTheme.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${discountPercent.toStringAsFixed(0)}% Rabatt',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Benefits checklist
                for (final b in benefits.take(_previewCount))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildBenefitLine(b, accent),
                  ),

                const SizedBox(height: 12),

                // Actions Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openPlan(plan, accent),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.45)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          l10n?.viewDetails ?? 'Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isCurrent || priceCents == null ? null : () => _quickJoin(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.brandGold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: Text(
                          isCurrent
                              ? (l10n?.currentPlan ?? 'Active')
                              : (l10n?.joinNow ?? 'Join Plan'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  // ===========================================================================
  // D. MEMBERSHIP CREDIT & LOYALTY SECTION
  // ===========================================================================
  Widget _buildCreditAndLoyaltySection(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        children: [
          // Wallet Credit Card
          InkWell(
            onTap: _openMyVouchers,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132018) : const Color(0xFFF2F6F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.brandGold.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGold.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppTheme.brandGoldDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDe ? 'Mitgliedsguthaben & Wallet' : 'Membership Credit & Wallet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          isDe
                              ? 'Guthaben wird automatisch an der Kasse angerechnet'
                              : 'Applied automatically to offset your orders at checkout',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.brandGoldDark),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Loyalty Rewards Card
          InkWell(
            onTap: _openLoyalty,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.loyaltyRewards ?? 'Ayubo Loyalty Rewards',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          isDe
                              ? 'Punkte bei jedem Einkauf sammeln & Prämien einlösen'
                              : 'Earn points on every order & unlock organic perks',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primaryGreen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PILLAR 2: GIFT VOUCHERS TAB CONTENT
  // ===========================================================================
  Widget _buildVouchersTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Voucher Header Banner
        _buildVoucherHeaderBanner(context),

        // 2. Quick Actions: My Vouchers & Claim Code
        _buildVoucherQuickActions(context),

        // 3. Denominations Grid
        _buildVoucherDenominations(context),

        // 4. Voucher Guidance Perks
        _buildVoucherPerks(context),

        // 5. FAQ Accordion
        _buildFaqSection(context),
      ],
    );
  }

  // ===========================================================================
  // A. VOUCHER HEADER BANNER
  // ===========================================================================
  Widget _buildVoucherHeaderBanner(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : const Color(0xFFFBF8F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.brandGoldDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n?.giftVoucherPromoTitle ?? 'The Gift of Ceylon Wellness',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isDe
                ? 'Schenken Sie Ihren Liebsten reine Ceylon-Bio-Vitalität. Digitale Gutscheine werden sofort per E-Mail zugestellt – ohne Versandkosten, mit 0% MwSt. und ohne Verfallsdatum.'
                : 'Give the gift of pure Ceylon vitality. Digital vouchers are delivered immediately via email with zero shipping fees, 0% VAT, and no expiration date.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // B. VOUCHER QUICK ACTIONS (MY VOUCHERS / CLAIM)
  // ===========================================================================
  Widget _buildVoucherQuickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openMyVouchers,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 15),
              label: Text(
                l10n?.myVouchers ?? 'My Vouchers',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary(context),
                side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _claimVoucherCode,
              icon: const Icon(Icons.qr_code_rounded, size: 15),
              label: Text(
                isDe ? 'Code einlösen' : 'Claim Code',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.brandGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // C. VOUCHER DENOMINATIONS GRID
  // ===========================================================================
  Widget _buildVoucherDenominations(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.voucherDenominations ?? 'Available Voucher Denominations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (_voucherAmounts.isNotEmpty)
                Text(
                  '${_voucherAmounts.length} ${isDe ? 'Werte' : 'Values'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isDe
                ? 'Wählen Sie den gewünschten Betrag zum direkten Kauf.'
                : 'Select a voucher amount to purchase and gift instantly.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),

          if (_voucherAmounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Center(
                child: Text(
                  isDe
                      ? 'Derzeit sind keine Gutscheinbeträge verfügbar.'
                      : 'No voucher denominations available currently.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context)),
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
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final amount = _voucherAmounts[index];
                return _buildVoucherCard(context, amount);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(BuildContext context, VoucherAmountData amount) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;
    final priceCents = (amount['price_cents'] as num?)?.toInt();
    final name = amount['name'] as String? ?? 'Gift Voucher';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.brandGold.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGold.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: AppTheme.primaryGreen,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_rounded, size: 12, color: AppTheme.brandGold),
                SizedBox(width: 4),
                Text(
                  'GIFT VOUCHER',
                  style: TextStyle(
                    color: AppTheme.brandGold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    priceCents != null ? formatCents(priceCents) : '—',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandGoldDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDe ? 'Sofortige E-Mail-Lieferung\n0% MwSt. · Kein Verfall' : 'Instant Email Delivery\n0% VAT · Never Expires',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.25,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Purchase Button
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ElevatedButton(
              onPressed: () => _showBuyVoucherSheet(amount),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandGold,
                foregroundColor: const Color(0xFF1B4332),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 7),
                elevation: 0,
              ),
              child: Text(
                l10n?.buyVoucher ?? 'Buy Voucher',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // D. VOUCHER PERKS GUIDANCE
  // ===========================================================================
  Widget _buildVoucherPerks(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final perks = isDe
        ? [
            ('Sofortige Zustellung', 'Gutscheincode kommt direkt nach dem Kauf per E-Mail.', Icons.email_outlined),
            ('Freie Produktauswahl', 'Für alle Gewürze, Tees und Kosmetikartikel einlösbar.', Icons.shopping_bag_outlined),
            ('Im Kundenkonto speichern', 'Guthaben kann direkt dem persönlichen Wallet zugebucht werden.', Icons.account_balance_wallet_outlined),
            ('Dauerhaft gültig', 'Kein Verfallsdatum – Restguthaben bleibt stets erhalten.', Icons.all_inclusive_rounded),
          ]
        : [
            ('Instant Email Delivery', 'Digital voucher code arrives immediately in recipient inbox.', Icons.email_outlined),
            ('Storewide Freedom', '100% redeemable on any organic Ceylon spices, teas & care.', Icons.shopping_bag_outlined),
            ('Account Wallet Integration', 'Claim directly to your account balance for seamless checkout.', Icons.account_balance_wallet_outlined),
            ('Never Expires', 'Voucher balance never expires and can be used across multiple orders.', Icons.all_inclusive_rounded),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDe ? 'Gutschein-Vorteile' : 'Voucher Features',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          for (final p in perks)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(p.$3, size: 16, color: AppTheme.brandGoldDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.$1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          p.$2,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FAQ ACCORDION (COMMON TO BOTH TABS)
  // ===========================================================================
  Widget _buildFaqSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final faqs = isDe
        ? [
            (
              'Wie funktioniert das 100% Einkaufsguthaben?',
              'Wenn Sie einer Mitgliedschaft beitreten, wird Ihnen der vollständige Mitgliedsbeitrag sofort als Einkaufsguthaben in Ihrem Kunden-Wallet gutgeschrieben. Sie können dieses Guthaben bei jedem Einkauf einlösen.',
            ),
            (
              'Gilt der Mitgliederrabatt auf alle Produkte?',
              'Ja! Ihr exklusiver Mitgliederrabatt wird automatisch bei jeder Bestellung auf das gesamte Sortiment angewendet, solange Ihre Mitgliedschaft aktiv ist.',
            ),
            (
              'Können Geschenkgutscheine mit Mitgliedsguthaben kombiniert werden?',
              'Ja. Gutscheincodes können dem Kunden-Wallet gutgeschrieben werden und lassen sich flexibel bei jeder Bestellung einsetzen.',
            ),
          ]
        : [
            (
              'How does 100% shopping credit back work?',
              'When you join an Ayubo Family tier, the full membership fee is immediately credited to your account wallet. You can spend it anytime on any organic products in our shop.',
            ),
            (
              'Does the member discount apply storewide?',
              'Yes! Your member discount is applied automatically during checkout across our entire catalog of Ceylon spices, teas, and wellness items.',
            ),
            (
              'Can gift vouchers be combined with membership credit?',
              'Yes. You can claim gift voucher codes directly into your wallet balance and combine them with your membership credit at checkout.',
            ),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDe ? 'Häufig gestellte Fragen' : 'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          for (final f in faqs)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: ExpansionTile(
                dense: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                shape: const Border(),
                title: Text(
                  f.$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.spa_rounded, size: 48, color: AppTheme.primaryGreen),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.brandGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // Screen Header Banner
            _buildScreenHeader(context),

            // Segment Switcher (Memberships | Gift Vouchers)
            _buildSegmentSwitcher(context),

            // Active Tab Content
            if (_selectedSection == 0)
              _buildMembershipsTab(context)
            else
              _buildVouchersTab(context),
          ],
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.familyTitle ?? 'Ayubo Family',
        subtitle: isDe ? 'Privilegien & Geschenke' : 'Privileges & Gifting',
        user: _user,
        showBackButton: Navigator.canPop(context),
        onProfileClosed: () {
          _load();
        },
      ),
      body: body,
      bottomNavigationBar: AppBottomBar(
        currentIndex: 2,
        user: _user,
      ),
    );
  }
}

// =============================================================================
// MODAL SHEET: VOUCHER QUANTITY & PURCHASE
// =============================================================================
class _VoucherPurchaseSheet extends StatefulWidget {
  final VoucherAmountData amount;
  final ValueChanged<int> onConfirm;

  const _VoucherPurchaseSheet({
    required this.amount,
    required this.onConfirm,
  });

  @override
  State<_VoucherPurchaseSheet> createState() => _VoucherPurchaseSheetState();
}

class _VoucherPurchaseSheetState extends State<_VoucherPurchaseSheet> {
  static const _max = 10;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    final priceCents = (widget.amount['price_cents'] as num?)?.toInt() ?? 0;
    final name = widget.amount['name'] as String? ?? 'Gift Voucher';
    final totalCents = priceCents * _quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132018) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.5), width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${formatCents(priceCents)} · ${isDe ? 'Sofort per E-Mail' : 'Instant Email Delivery'}',
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
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardSubtleColor(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Text(
                isDe
                    ? '• Zustellung sofort nach Zahlung per E-Mail.\n• Gültig für das gesamte Sortiment mit 0% MwSt.\n• Keine Versandgebühren, kein Verfallsdatum.'
                    : '• Delivered instantly by email upon order payment.\n• 100% redeemable storewide with 0% VAT.\n• No shipping fees, no expiration date.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quantity Stepper
            Row(
              children: [
                Text(
                  isDe ? 'Menge' : 'Quantity',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Decrease',
                  visualDensity: VisualDensity.compact,
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  color: AppTheme.primaryGreen,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.brandGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase',
                  visualDensity: VisualDensity.compact,
                  onPressed: _quantity < _max ? () => setState(() => _quantity++) : null,
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add to Cart Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onConfirm(_quantity),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.brandGold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  '${isDe ? 'In den Warenkorb' : 'Add to Cart'} · ${formatCents(totalCents)}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
