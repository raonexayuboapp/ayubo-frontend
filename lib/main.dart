import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ayubo Organics',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}