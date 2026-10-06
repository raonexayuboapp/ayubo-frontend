import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/navigation.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Placeholder until the real modules (shop, cart, vouchers...) exist.
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Map<String, dynamic> _user = widget.user;

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(user: _user)),
    );
    // Refresh the name shown here in case it was edited.
    try {
      final fresh = await ApiService.instance.me();
      if (mounted) setState(() => _user = fresh);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await ApiService.instance.logout();
    if (mounted) goTo(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayubo Organics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My profile',
            onPressed: _openProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, ${_user['first_name']} ${_user['last_name']}',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}