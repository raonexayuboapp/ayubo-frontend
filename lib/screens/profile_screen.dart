
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation.dart';
import '../utils/validators.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_button.dart';
import '../widgets/password_field.dart';
import 'addresses_screen.dart';
import 'change_password_screen.dart';
import 'favourites_screen.dart';
import 'home_screen.dart';

import 'loyalty_screen.dart';
import 'orders_screen.dart';
import 'vouchers_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _first = TextEditingController(
    text: widget.user['first_name']?.toString() ?? '',
  );

  late final TextEditingController _last = TextEditingController(
    text: widget.user['last_name']?.toString() ?? '',
  );

  late final TextEditingController _mobile = TextEditingController(
    text: widget.user['mobile_number']?.toString() ?? '',
  );

  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _surface =>
      _isDark ? AppTheme.surfaceDark : Colors.white;

  Color get _border =>
      _isDark ? AppTheme.borderDark : AppTheme.borderLight;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    try {
      await ApiService.instance.updateProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        mobileNumber: _mobile.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (deleted == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);

      goTo(context, const HomeScreen(user: null));

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account was deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    TextInputType? type,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        textCapitalization: type == TextInputType.phone
            ? TextCapitalization.none
            : TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[key],
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 20,
                )
              : null,
          filled: true,
          fillColor: _isDark
              ? AppTheme.bgDark.withValues(alpha: 0.5)
              : AppTheme.bgLight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: scheme.outline.withValues(alpha: 0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppTheme.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final firstName = _first.text.trim();
    final lastName = _last.text.trim();
    final email = widget.user['email']?.toString() ?? '';

    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}'
        '${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.brandGold,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandGold.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? 'A' : initials,
                style: const TextStyle(
                  color: AppTheme.brandGoldLight,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            '$firstName $lastName'.trim().isEmpty
                ? 'Ayubo Member'
                : '$firstName $lastName'.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 17),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppTheme.brandGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.brandGold.withValues(alpha: 0.5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppTheme.brandGoldLight,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  'AYUBO MEMBER',
                  style: TextStyle(
                    color: AppTheme.brandGoldLight,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalDetailsCard() {
    final scheme = Theme.of(context).colorScheme;
    final email = widget.user['email']?.toString() ?? '';
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.primaryGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.personalDetails ?? 'Personal Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      l10n?.managePersonalInfo ?? 'Manage your personal information',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          TextFormField(
            initialValue: email,
            enabled: false,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.55),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: l10n?.emailAddress ?? 'Email address',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: scheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
              suffixIcon: Tooltip(
                message: 'Email cannot be changed',
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              filled: true,
              fillColor: _isDark
                  ? AppTheme.bgDark.withValues(alpha: 0.3)
                  : AppTheme.bgLight.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'first_name',
                  l10n?.firstName ?? 'First name',
                  _first,
                  (v) => Validators.name(v, l10n?.firstName ?? 'First name'),
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'last_name',
                  l10n?.lastName ?? 'Last name',
                  _last,
                  (v) => Validators.name(v, l10n?.lastName ?? 'Last name'),
                ),
              ),
            ],
          ),

          _field(
            'mobile_number',
            l10n?.mobileNumber ?? 'Mobile number',
            _mobile,
            Validators.mobile,
            type: TextInputType.phone,
            icon: Icons.phone_outlined,
          ),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.error.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 19,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          LoadingButton(
            label: l10n?.saveChanges ?? 'Save Changes',
            loading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
    bool showChevron = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = iconColor ?? AppTheme.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _border,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor ?? scheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            : null,
        trailing: showChevron
            ? Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.4),
                size: 22,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _accountActivity() {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          l10n?.accountActivity ?? 'Account Activity',
          subtitle: isDe ? 'Ihre Adressen, Bestellungen und gemerkten Artikel' : 'Your addresses, orders and saved items',
        ),

        _actionTile(
          icon: Icons.location_on_outlined,
          title: l10n?.savedAddresses ?? 'Saved addresses',
          subtitle: isDe ? 'Lieferadressen verwalten' : 'Manage your delivery addresses',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddressesScreen(
                defaultRecipient:
                    '${_first.text.trim()} ${_last.text.trim()}'.trim(),
              ),
            ),
          ),
        ),

        _actionTile(
          icon: Icons.favorite_border_rounded,
          title: l10n?.myFavourites ?? 'My favourites',
          subtitle: isDe ? 'Ihre gemerkten Produkte' : 'Products you have saved',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FavouritesScreen(),
            ),
          ),
        ),

        _actionTile(
          icon: Icons.receipt_long_outlined,
          title: l10n?.myOrders ?? 'My orders',
          subtitle: isDe ? 'Bestellverlauf und Details anzeigen' : 'View your order history and details',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrdersScreen(user: widget.user),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rewardsSection() {
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          l10n?.loyaltyRewards ?? 'Ayubo Rewards',
          subtitle: isDe ? 'Ihre Mitgliedervorteile und Treueprämien' : 'Enjoy your membership benefits and rewards',
        ),

        _actionTile(
          icon: Icons.card_giftcard_rounded,
          iconColor: AppTheme.brandGoldDark,
          title: l10n?.myVouchers ?? 'My vouchers and credit',
          subtitle: isDe ? 'Verfügbare Gutscheine und Guthaben anzeigen' : 'View available vouchers and account credit',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VouchersScreen(),
            ),
          ),
        ),

        _actionTile(
          icon: Icons.stars_rounded,
          iconColor: AppTheme.brandGoldDark,
          title: l10n?.loyaltyPoints ?? 'My points and rewards',
          subtitle: isDe ? 'Punktestand und Treueprämien prüfen' : 'Check your loyalty points and rewards',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LoyaltyScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountSettings() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          l10n?.accountSettings ?? 'Account Settings',
          subtitle: isDe ? 'Konto und Sicherheit verwalten' : 'Manage your account and security',
        ),

        _actionTile(
          icon: Icons.lock_reset_rounded,
          title: l10n?.changePassword ?? 'Change password',
          subtitle: isDe ? 'Schützen Sie Ihr Konto' : 'Keep your account secure',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangePasswordScreen(
                email: widget.user['email']?.toString() ?? '',
              ),
            ),
          ),
        ),

        _actionTile(
          icon: Icons.logout_rounded,
          title: l10n?.logout ?? 'Log out',
          subtitle: isDe ? 'Von Ihrem Konto abmelden' : 'Sign out of your account',
          showChevron: false,
          onTap: () async {
            await ApiService.instance.logout();

            if (mounted) {
              goTo(context, const HomeScreen(user: null));
            }
          },
        ),

        const SizedBox(height: 12),

        _actionTile(
          icon: Icons.delete_forever_outlined,
          iconColor: scheme.error,
          textColor: scheme.error,
          title: l10n?.deleteAccount ?? 'Delete account',
          subtitle: isDe ? 'Konto dauerhaft löschen' : 'Permanently delete your account',
          showChevron: false,
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: l10n?.myProfile ?? 'My Profile',
        subtitle: isDe ? 'Konto & Einstellungen' : 'Account & Preferences',
        user: widget.user,
        showProfile: false,
        showBackButton: Navigator.canPop(context),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          children: [
            _profileHeader(),

            const SizedBox(height: 28),

            _personalDetailsCard(),

            const SizedBox(height: 30),

            _accountActivity(),

            const SizedBox(height: 20),

            _rewardsSection(),

            const SizedBox(height: 20),

            _accountSettings(),

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        color: AppTheme.primaryGreen,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AYUBO ORGANICS',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Naturally better, naturally you.',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: 4,
        user: widget.user,
      ),
    );
  }
}

// ============================================================
// DELETE ACCOUNT DIALOG
// ============================================================

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  bool _loading = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() {
        _fieldError = 'Password is required.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _fieldError = null;
      _error = null;
    });

    try {
      await ApiService.instance.deleteAccount(_password.text);

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _fieldError = e.fieldErrors['password'];
        _error = _fieldError == null ? e.message : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor = scheme.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: errorColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delete account?',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This action cannot be undone. Your profile, saved addresses, '
            'and active rewards will be removed permanently. '
            'Enter your password to confirm deletion.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          PasswordField(
            controller: _password,
            label: 'Confirm Password',
            serverError: _fieldError,
            action: TextInputAction.done,
            onSubmitted: (_) => _delete(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: errorColor,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: errorColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _loading ? null : _delete,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Text('Delete Account'),
        ),
      ],
    );
  }
}
