
import 'dart:convert';

/// Client-side checks for fast feedback.
/// The backend must enforce the same rules independently.
class Validators {
  static final RegExp _email =
  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static final RegExp _name = RegExp(
    r"^[\p{L}][\p{L}\p{M} .'-]*$",
    unicode: true,
  );

  static final RegExp _mobile = RegExp(r'^\+?[0-9]{9,15}$');

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{N}', unicode: true);
  static final RegExp _code = RegExp(r'^[0-9]{6}$');

  static String? required(String? v, String label) {
    if (v == null || v.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  static String? name(String? v, String label) {
    final s = (v ?? '').trim();

    if (s.isEmpty) {
      return '$label is required.';
    }

    if (s.length > 50) {
      return '$label must be 50 characters or fewer.';
    }

    if (!_name.hasMatch(s)) {
      return '$label contains invalid characters.';
    }

    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();

    if (s.isEmpty) {
      return 'Email is required.';
    }

    if (s.length > 254 || !_email.hasMatch(s)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  static String? mobile(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s\-()]'), '');

    if (s.isEmpty) {
      return 'Mobile number is required.';
    }

    if (!_mobile.hasMatch(s)) {
      return 'Enter 9 to 15 digits, optionally starting with +.';
    }

    return null;
  }

  static String? password(String? v, {String? email}) {
    final s = v ?? '';

    if (s.isEmpty) {
      return 'Password is required.';
    }

    // Check UTF-8 byte length for compatibility with bcrypt-based backends.
    final bytes = utf8.encode(s).length;

    if (bytes < 8 || bytes > 72) {
      return 'Use 8 to 72 characters.';
    }

    if (!_letter.hasMatch(s) || !_digit.hasMatch(s)) {
      return 'Include at least one letter and one number.';
    }

    if (email != null &&
        s.toLowerCase() == email.trim().toLowerCase()) {
      return 'Password must not be your email address.';
    }

    return null;
  }

  static String? confirm(String? v, String original) {
    if (v == null || v.isEmpty) {
      return 'Please confirm your password.';
    }

    if (v != original) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String? code(String? v) {
    return _code.hasMatch(v ?? '')
        ? null
        : 'Enter the 6-digit code.';
  }
}
