import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/organic_loading_screen.dart';
import 'home_screen.dart';

typedef UserData = Map<String, dynamic>;

/// Startup:
/// - Valid stored session: Home with authenticated user.
/// - No session: Home in guest mode.
/// - Invalid or expired session: Home in guest mode.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<UserData?> _check = _load();

  Future<UserData?> _load() async {
    try {
      if (!await ApiService.instance.hasToken()) {
        return null;
      }
      return await ApiService.instance.me();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserData?>(
      future: _check,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const OrganicLoadingScreen(
            message: 'Loading Ayubo Organics...',
          );
        }

        // Both authenticated and guest users enter HomeScreen.
        return HomeScreen(user: snap.data);
      },
    );
  }
}
