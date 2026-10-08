import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'dart:ui' show PointerDeviceKind;

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
      scrollBehavior: AppScrollBehavior(),
    );
  }
}
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
