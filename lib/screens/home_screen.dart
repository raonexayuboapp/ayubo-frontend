import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Map<String, dynamic> _user = widget.user;

  /// Called when the profile screen closes, in case the name was edited.
  Future<void> _refreshUser() async {
    try {
      final fresh = await ApiService.instance.me();
      if (mounted) setState(() => _user = fresh);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(user: _user, onProfileClosed: _refreshUser),
      body: Center(
        child: Text(
          'Welcome, ${_user['first_name']} ${_user['last_name']}',
          style: const TextStyle(fontSize: 22),
        ),
      ),
      bottomNavigationBar: AppBottomBar(currentIndex: 0,),
    );
  }
}