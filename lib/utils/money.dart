/// "100", "100.5", "100,50" -> cents. Returns null if the text is not a valid amount.
int? parseEuroToCents(String input) {
  final s = input.trim().replaceAll(',', '.');
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final euros = int.parse(m.group(1)!);
  final fraction = int.parse((m.group(2) ?? '0').padRight(2, '0')); // "5" means 50 cents
  return euros * 100 + fraction;
}

String formatCents(int cents) =>
    '€${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
/// 5.0 -> "5", 7.5 -> "7.5"
String formatPercent(num d) => d == d.roundToDouble() ? '${d.toInt()}' : '$d';

/// 10.0 -> "10", 2.5 -> "2.5", 0.125 -> "0.125"
String formatQuantity(num n) {
  if (n == n.roundToDouble()) return '${n.toInt()}';
  return n.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
}