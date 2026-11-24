import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/localized_content.dart';

typedef UserData = Map<String, dynamic>;

class AdminUserDetailsScreen extends StatefulWidget {
  final UserData user;
  final int currentUserId;

  const AdminUserDetailsScreen({
    super.key,
    required this.user,
    required this.currentUserId,
  });

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  late UserData _user;
  UserData? _membership;

  bool _loadingMembership = true;
  bool _membershipActionLoading = false;
  bool _accountActionLoading = false;

  String? _membershipError;

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  // Compare the actual user ID, not the customer ID.
  bool get _isSelf => _toInt(_user['id']) == widget.currentUserId;

  int? get _customerId => _toInt(_user['customer_id']);

  int? get _membershipId => _toInt(_membership?['id']);

  String get _membershipStatus =>
      (_membership?['status'] ?? '').toString().trim().toLowerCase();

  bool get _accountEnabled {
    final value = _user['is_active'];

    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'active';
  }

  bool get _emailVerified {
    final value = _user['email_verified'];

    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'verified';
  }

  String get _role => (_user['role'] ?? 'customer').toString().toLowerCase();

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _loadMembership();
  }

  String _display(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not available';
    }
    return value.toString();
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not available';
    }

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatCredit(dynamic cents) {
    final amount = _toInt(cents);
    if (amount == null) return 'Not available';
    return '€${(amount / 100).toStringAsFixed(2)}';
  }

  String _fullName() {
    final firstName = (_user['first_name'] ?? '').toString().trim();
    final lastName = (_user['last_name'] ?? '').toString().trim();
    final name = '$firstName $lastName'.trim();

    return name.isEmpty ? 'Unnamed user' : name;
  }

  Future<void> _loadMembership() async {
    if (_customerId == null) {
      if (!mounted) return;

      setState(() {
        _membership = null;
        _membershipError = null;
        _loadingMembership = false;
      });
      return;
    }

    setState(() {
      _loadingMembership = true;
      _membershipError = null;
    });

    try {
      final memberships = await ApiService.instance.adminListMemberships();

      UserData? matchingMembership;

      for (final membership in memberships) {
        if (_toInt(membership['customer_id']) == _customerId) {
          matchingMembership = membership;
          break;
        }
      }

      if (matchingMembership == null) {
        if (!mounted) return;

        setState(() {
          _membership = null;
          _loadingMembership = false;
        });
        return;
      }

      final membershipId = _toInt(matchingMembership['id']);

      if (membershipId == null) {
        throw Exception('The membership record has an invalid ID.');
      }

      final details = await ApiService.instance.adminGetMembership(
        membershipId,
      );

      if (!mounted) return;

      setState(() {
        _membership = details;
        _loadingMembership = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _membershipError = e.toString();
        _loadingMembership = false;
      });
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _updateMembership(String newStatus) async {
    if (_isSelf || _membershipId == null || _membershipActionLoading) {
      return;
    }

    final action = switch (newStatus) {
      'paused' => 'pause',
      'active' => 'resume',
      'cancelled' => 'cancel',
      _ => newStatus,
    };

    final confirmed = await _confirm(
      title: '${action[0].toUpperCase()}${action.substring(1)} membership?',
      message: switch (newStatus) {
        'paused' =>
          'This will pause the customer membership. The customer will not be able to use membership benefits while paused.',
        'active' => 'This will resume the paused membership.',
        'cancelled' =>
          'This will permanently cancel the customer membership. This action cannot be undone.',
        _ => 'Are you sure you want to continue?',
      },
      confirmText: action[0].toUpperCase() + action.substring(1),
      destructive: newStatus == 'cancelled',
    );

    if (!confirmed || !mounted) return;

    setState(() => _membershipActionLoading = true);

    try {
      await ApiService.instance.adminUpdateMembership(_membershipId!, {
        'status': newStatus,
      });

      await _loadMembership();

      if (!mounted) return;

      final successMessage = switch (newStatus) {
        'paused' => 'Membership paused successfully.',
        'active' => 'Membership resumed successfully.',
        'cancelled' => 'Membership cancelled successfully.',
        _ => 'Membership updated successfully.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not $action membership: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _membershipActionLoading = false);
      }
    }
  }

  Future<void> _updateAccount(Map<String, dynamic> body) async {
    if (_isSelf || _accountActionLoading) return;

    final userId = _toInt(_user['id']);
    if (userId == null) return;

    setState(() => _accountActionLoading = true);

    try {
      final updatedUser = await ApiService.instance.adminUpdateUser(
        userId,
        body,
      );

      if (!mounted) return;

      // Always use the backend response.
      // The backend may reject activation when email is unverified.
      setState(() {
        _user = Map<String, dynamic>.from(updatedUser);
      });

      String message;

      if (body.containsKey('is_active')) {
        message = _accountEnabled
            ? 'Account enabled successfully.'
            : 'Account remains disabled or pending verification.';
      } else if (body.containsKey('role')) {
        message = _role == 'admin'
            ? 'Administrator role assigned successfully.'
            : 'Administrator role removed successfully.';
      } else {
        message = 'Account updated successfully.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update account: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _accountActionLoading = false);
      }
    }
  }

  Future<void> _toggleAccountStatus() async {
    if (_isSelf || _accountActionLoading) return;

    final enable = !_accountEnabled;

    // Do not offer activation for an unverified email.
    // Backend verification rules must remain enforced.
    if (enable && !_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account cannot be enabled until the email address is verified.',
          ),
        ),
      );
      return;
    }

    final confirmed = await _confirm(
      title: enable ? 'Enable account?' : 'Disable account?',
      message: enable
          ? 'This will enable the customer account.'
          : 'This will disable the customer account and revoke its active login sessions.',
      confirmText: enable ? 'Enable' : 'Disable',
      destructive: !enable,
    );

    if (!confirmed || !mounted) return;

    await _updateAccount({'is_active': enable});
  }

  Future<void> _toggleRole() async {
    if (_isSelf || _accountActionLoading) return;

    final makeAdmin = _role != 'admin';
    final newRole = makeAdmin ? 'admin' : 'customer';

    final confirmed = await _confirm(
      title: makeAdmin ? 'Make administrator?' : 'Remove administrator role?',
      message: makeAdmin
          ? 'This will grant this user administrator access.'
          : 'This will remove administrator access from this user.',
      confirmText: makeAdmin ? 'Make admin' : 'Remove admin',
      destructive: !makeAdmin,
    );

    if (!confirmed || !mounted) return;

    await _updateAccount({'role': newRole});
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'inactive':
        return Colors.blueGrey;
      case 'expired':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green.shade800),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              _display(value),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Dedicated status row: does not display "Not available".
  Widget _membershipStatusRow(String status) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              l10n?.adminProductStatus ?? 'Status',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: _statusBadge(status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    final label = status.isEmpty
        ? 'Unknown'
        : status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _accountSection() {
    final l10n = AppLocalizations.of(context);
    return _sectionCard(
      title: l10n?.adminUserDetails ?? 'Account information',
      icon: Icons.person_outline,
      children: [
        _detailRow('User ID', _user['id']),
        _detailRow('Customer ID', _user['customer_id']),
        _detailRow('Name', _fullName()),
        _detailRow('Email', _user['email']),
        _detailRow('Phone', _user['phone'] ?? _user['mobile_number']),
        _detailRow(
          l10n?.adminEmailVerified ?? 'Email verification',
          _emailVerified
              ? (l10n?.adminEmailVerified ?? 'Verified')
              : (l10n?.adminEmailUnverified ?? 'Not verified'),
        ),
        _detailRow(
          l10n?.adminAccountStatus ?? 'Account status',
          _accountEnabled
              ? (l10n?.adminAccountEnabled ?? 'Enabled')
              : (l10n?.adminAccountDisabled ?? 'Disabled'),
        ),
        _detailRow('Role', localizedUserRole(_role, context: context)),
        const Divider(height: 24),

        if (_isSelf)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'You are viewing your own administrator account. '
              'The account actions below are disabled.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSelf || _accountActionLoading
                ? null
                : _toggleAccountStatus,
            icon: Icon(
              _accountEnabled ? Icons.block : Icons.check_circle_outline,
            ),
            label: Text(
              _accountEnabled
                  ? (l10n?.adminDisableAccount ?? 'Disable account')
                  : (l10n?.adminEnableAccount ?? 'Enable account'),
            ),
            style: _accountEnabled
                ? OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSelf || _accountActionLoading ? null : _toggleRole,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(
              _role == 'admin'
                  ? 'Remove administrator role'
                  : (l10n?.adminChangeRole ?? 'Make administrator'),
            ),
          ),
        ),
        if (_accountActionLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _membershipActionButtons(String status) {
    final canManage =
        !_isSelf && !_membershipActionLoading && _membershipId != null;
    final l10n = AppLocalizations.of(context);

    final isActive = status == 'active';
    final isPaused = status == 'paused';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),

        if (_isSelf)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Membership actions are disabled for your own account.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

        if (isActive || isPaused) ...[
          if (isActive)
            OutlinedButton.icon(
              onPressed: canManage ? () => _updateMembership('paused') : null,
              icon: const Icon(Icons.pause_circle_outline),
              label: Text(l10n?.adminPauseMembership ?? 'Pause membership'),
            )
          else
            FilledButton.icon(
              onPressed: canManage ? () => _updateMembership('active') : null,
              icon: const Icon(Icons.play_circle_outline),
              label: Text(l10n?.adminResumeMembership ?? 'Resume membership'),
            ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: canManage ? () => _updateMembership('cancelled') : null,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(l10n?.adminCancelMembership ?? 'Cancel membership'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
          ),
        ] else
          const Text(
            'No manual membership actions are available for this status.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

        if (_membershipActionLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _membershipSection() {
    final l10n = AppLocalizations.of(context);
    if (_loadingMembership) {
      return _sectionCard(
        title: l10n?.adminMembership ?? 'Membership',
        icon: Icons.card_membership,
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_membershipError != null) {
      return _sectionCard(
        title: l10n?.adminMembership ?? 'Membership',
        icon: Icons.card_membership,
        children: [
          Text(
            'Could not load membership information.',
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          Text(_membershipError!, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadMembership,
            icon: const Icon(Icons.refresh),
            label: Text(l10n?.adminRetry ?? 'Retry'),
          ),
        ],
      );
    }

    if (_customerId == null) {
      return _sectionCard(
        title: l10n?.adminMembership ?? 'Membership',
        icon: Icons.card_membership,
        children: const [
          Text(
            'This user does not have a customer profile.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    if (_membership == null) {
      return _sectionCard(
        title: l10n?.adminMembership ?? 'Membership',
        icon: Icons.card_membership,
        children: const [
          Text(
            'This customer does not currently have a membership.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    final status = _membershipStatus;

    return _sectionCard(
      title: l10n?.adminMembership ?? 'Membership',
      icon: Icons.card_membership,
      children: [
        _detailRow('Membership ID', _membership?['id']),
        _detailRow('Plan', _membership?['plan_name']),
        _detailRow('Plan code', _membership?['plan_code']),
        _detailRow(
          l10n?.adminMemberNumber ?? 'Member number',
          _membership?['member_number'],
        ),
        _membershipStatusRow(status),
        _detailRow(
          l10n?.adminJoinedOn ?? 'Joined',
          _formatDate(_membership?['joined_at']),
        ),
        _detailRow(
          l10n?.adminExpiresOn ?? 'Expires',
          _formatDate(_membership?['expires_at']),
        ),
        _detailRow(
          l10n?.adminAvailableCredit ?? 'Available shopping credit',
          _formatCredit(_membership?['spendable_cents']),
        ),
        _membershipActionButtons(status),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.adminUserDetails ?? 'User details')),
      body: RefreshIndicator(
        onRefresh: _loadMembership,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(
              title: l10n?.adminCustomerDetails ?? 'Customer',
              icon: Icons.account_circle_outlined,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _fullName(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _display(_user['email']),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
            _accountSection(),
            _membershipSection(),
          ],
        ),
      ),
    );
  }
}
