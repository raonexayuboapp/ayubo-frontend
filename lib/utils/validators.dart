import 'dart:convert';

/// Client-side checks for fast feedback. The server enforces the same rules again.
class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _name = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M} .'-]*$", unicode: true);
  static final _mobile = RegExp(r'^\+?[0-9]{9,15}$');
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _digit = RegExp(r'\p{N}', unicode: true);

  static String? required(String? v, String label) =>
      (v == null || v.isEmpty) ? '$label is required.' : null;

  static String? name(String? v, String label) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '$label is required.';
    if (s.length > 50) return '$label must be 50 characters or fewer.';
    if (!_name.hasMatch(s)) return '$label contains invalid characters.';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required.';
    if (s.length > 254 || !_email.hasMatch(s)) return 'Enter a valid email address.';
    return null;
  }

  static String? mobile(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.isEmpty) return 'Mobile number is required.';
    if (!_mobile.hasMatch(s)) return 'Enter 9 to 15 digits, optionally starting with +.';
    return null;
  }

  static String? password(String? v, {String? email}) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required.';
    final bytes = utf8.encode(s).length;
    if (bytes < 8 || bytes > 72) return 'Use 8 to 72 characters.';
    if (!_letter.hasMatch(s) || !_digit.hasMatch(s)) return 'Include at least one letter and one number.';
    if (email != null && s.toLowerCase() == email.trim().toLowerCase()) {
      return 'Password must not be your email address.';
    }
    return null;
  }

  static String? confirm(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password.';
    if (v != original) return 'Passwords do not match.';
    return null;
  }

  static String? code(String? v) =>
      RegExp(r'^[0-9]{6}$').hasMatch(v ?? '') ? null : 'Enter the 6-digit code.';
}