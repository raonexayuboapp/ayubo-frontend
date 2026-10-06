import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final int currentUserId;
  const AdminUsersScreen({super.key, required this.currentUserId});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
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
      final data = await ApiService.instance.adminListUsers(search: _search.text.trim(), page: _page);
      final list = (data['users'] as List<dynamic>).cast<Map<String, dynamic>>();
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

  Future<void> _apply(Map<String, dynamic> user, String title, Map<String, dynamic> body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('${user['first_name']} ${user['last_name']} (${user['email']})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final updated = await ApiService.instance.adminUpdateUser(user['id'] as int, body);
      if (!mounted) return;
      setState(() {
        final i = _users.indexWhere((u) => u['id'] == updated['id']);
        if (i >= 0) _users[i] = updated;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _actions(Map<String, dynamic> user) {
    if (user['id'] == widget.currentUserId) return; // the server also blocks this
    final active = user['is_active'] == true;
    final isAdmin = user['role'] == 'admin';

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(active ? Icons.block : Icons.check_circle_outline),
              title: Text(active ? 'Disable account' : 'Enable account'),
              onTap: () {
                Navigator.pop(context);
                _apply(user, active ? 'Disable this account?' : 'Enable this account?',
                    {'is_active': !active});
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(isAdmin ? 'Remove admin role' : 'Make admin'),
              onTap: () {
                Navigator.pop(context);
                _apply(user, isAdmin ? 'Remove admin role?' : 'Make this user an admin?',
                    {'role': isAdmin ? 'customer' : 'admin'});
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _users.length < _total;

    Widget body;
    if (_loading && _users.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _users.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ]),
      );
    } else if (_users.isEmpty) {
      body = const Center(child: Text('No users found.'));
    } else {
      body = ListView.builder(
        itemCount: _users.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _users.length) {
            return TextButton(
              onPressed: _loading
                  ? null
                  : () {
                _page++;
                _load(reset: false);
              },
              child: const Text('Load more'),
            );
          }
          final u = _users[i];
          return ListTile(
            onTap: () => _actions(u),
            title: Text('${u['first_name']} ${u['last_name']}'),
            subtitle: Text('${u['email']}\n${u['mobile_number']}'),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 4,
              children: [
                if (u['role'] == 'admin')
                  const Chip(label: Text('Admin'), visualDensity: VisualDensity.compact),
                if (u['is_active'] != true)
                  const Chip(label: Text('Disabled'), visualDensity: VisualDensity.compact),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Users ($_total)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, email or mobile',
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}