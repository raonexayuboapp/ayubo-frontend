import 'package:flutter/material.dart';

/// Replaces the whole navigation stack with [screen].
void goTo(BuildContext context, Widget screen) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => screen),
    (_) => false,
  );
}
