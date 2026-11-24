import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/localized_content.dart';
import 'admin_user_details_screen.dart';

typedef UserData = Map<String, dynamic>;

class AdminUsersScreen extends StatefulWidget {
  final int currentUserId;
  const AdminUsersScreen({super.key, required this.currentUserId});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  List<UserData> _users = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) _page = 1;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.instance.adminListUsers(
        search: _search.text.trim(),
        page: _page,
      );

      final list = (data['users'] as List<dynamic>).cast<UserData>();
      final meta = data['meta'] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _users = reset ? list : [..._users, ...list];
        _total = meta['total'] as int;
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

  Future<void> _openUserDetails(UserData user) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailsScreen(
          user: user,
          currentUserId: widget.currentUserId,
        ),
      ),
    );

    if (!mounted) return;

    // Refresh the list in case account information was changed.
    await _load(reset: true);
  }

  Widget _buildRoleBadge(BuildContext context, String role) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: goldColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        localizedUserRole(role, context: context).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: goldColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDisabledBadge(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        localizedUserStatus(false, context: context),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);
    final hasMore = _users.length < _total;

    Widget body;

    if (_loading && _users.isEmpty) {
      body = Center(
        child: CircularProgressIndicator(color: goldColor, strokeWidth: 2),
      );
    } else if (_error != null && _users.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n?.adminRetry ?? 'Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    } else if (_users.isEmpty) {
      body = Center(
        child: Text(
          l10n?.adminNoUsersFound ?? 'No users found.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _users.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
        itemBuilder: (_, i) {
          if (i == _users.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? CircularProgressIndicator(
                        color: goldColor,
                        strokeWidth: 2,
                      )
                    : TextButton(
                        onPressed: () {
                          _page++;
                          _load(reset: false);
                        },
                        child: Text(
                          l10n?.adminLoadMore ?? 'Load more',
                          style: TextStyle(
                            color: goldColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            );
          }

          final u = _users[i];
          final isCurrentUser = u['id'] == widget.currentUserId;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            onTap: () => _openUserDetails(u),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                u['role'] == 'admin'
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline,
                color: u['role'] == 'admin'
                    ? goldColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    '${u['first_name']} ${u['last_name']}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(You)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: goldColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${u['email']}\n${u['mobile_number'] ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (u['role'] == 'admin') ...[
                  _buildRoleBadge(context, 'admin'),
                  const SizedBox(width: 4),
                ],
                if (u['is_active'] != true) _buildDisabledBadge(context),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n?.adminUsers ?? 'Users'} ($_total)'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                hintText:
                    l10n?.adminSearchUsersHint ??
                    'Search name, email or mobile...',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
