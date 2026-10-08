import 'package:flutter/material.dart';

import 'admin_plans_screen.dart';
import 'admin_users_screen.dart';

class AdminMenuScreen extends StatelessWidget {
  final int currentUserId;
  const AdminMenuScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Users'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AdminUsersScreen(currentUserId: currentUserId))),
          ),
          ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: const Text('Membership plans'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AdminPlansScreen())),
          ),
        ],
      ),
    );
  }
}