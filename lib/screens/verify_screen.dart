import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/navigation.dart';
import 'login_screen.dart';

class VerifyScreen extends StatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  int _cooldown = 60; // the backend enforces 60 s between resends
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.instance.verifyEmail(
        email: widget.email,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      goTo(context, const LoginScreen());
      messenger.showSnackBar(
        const SnackBar(content: Text('Email verified. Please log in.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors['code'] ?? e.message;
        _loading = false;
      });
    }
  }

  Future<void> _resend() async {
    try {
      await ApiService.instance.resendVerification(widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If the account needs it, a new code was sent.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'We sent a 6-digit code to ${widget.email}. It expires in 10 minutes.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 8),
            decoration: const InputDecoration(counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _verify,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
          TextButton(
            onPressed: _cooldown > 0 ? null : _resend,
            child: Text(
              _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
            ),
          ),
        ],
      ),
    );
  }
}
