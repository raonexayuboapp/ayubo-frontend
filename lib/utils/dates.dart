import 'money.dart';

/// The server sends UTC as "2026-10-25 09:30:00". This is the device's local time, or null if unreadable.
DateTime? parseServerTime(String? stamp) {
  if (stamp == null || stamp.isEmpty) return null;
  return DateTime.tryParse('${stamp.replaceFirst(' ', 'T')}Z')?.toLocal();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// German: 25.10.2026 | English: 25/10/2026
String formatDate(String? stamp, [String? locale]) {
  final d = parseServerTime(stamp);
  if (d == null) return '';
  final loc = locale ?? currentAppLocale;
  if (loc.startsWith('de')) {
    return '${_two(d.day)}.${_two(d.month)}.${d.year}';
  }
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// German: 25.10.2026, 14:05 Uhr | English: 25/10/2026, 14:05
String formatDateTime(String? stamp, [String? locale]) {
  final d = parseServerTime(stamp);
  if (d == null) return '';
  final loc = locale ?? currentAppLocale;
  final date = formatDate(stamp, loc);
  if (loc.startsWith('de')) {
    return '$date, ${_two(d.hour)}:${_two(d.minute)} Uhr';
  }
  return '$date, ${_two(d.hour)}:${_two(d.minute)}';
}
