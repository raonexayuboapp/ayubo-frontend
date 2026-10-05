import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Startup: a valid stored token goes to Home, otherwise Login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Map<String, dynamic>?> _check = _load();

  Future<Map<String, dynamic>?> _load() async {
    if (!await ApiService.instance.hasToken()) return null;
    try {
      return await ApiService.instance.me();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _check,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        return user == null ? const LoginScreen() : HomeScreen(user: user);
      },
    );
  }
}
