import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/navigation.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

/// Placeholder until the real modules (shop, cart, vouchers...) exist.
class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    await ApiService.instance.logout();
    if (context.mounted) goTo(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayubo Organics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset),
            tooltip: 'Change password',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(email: user['email'] as String),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, ${user['first_name']} ${user['last_name']}',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}