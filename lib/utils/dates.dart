/// The server sends UTC as "2026-10-25 09:30:00". This is the device's local time, or null if unreadable.
DateTime? parseServerTime(String? stamp) {
  if (stamp == null || stamp.isEmpty) return null;
  return DateTime.tryParse('${stamp.replaceFirst(' ', 'T')}Z')?.toLocal();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 25.10.2026
String formatDate(String? stamp) {
  final d = parseServerTime(stamp);
  return d == null ? '' : '${_two(d.day)}.${_two(d.month)}.${d.year}';
}

/// 25.10.2026, 14:05
String formatDateTime(String? stamp) {
  final d = parseServerTime(stamp);
  return d == null ? '' : '${formatDate(stamp)}, ${_two(d.hour)}:${_two(d.minute)}';
}