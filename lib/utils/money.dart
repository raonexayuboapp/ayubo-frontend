/// Global current app locale for formatting. Defaults to 'en'.
String currentAppLocale = 'en';

/// Formats integer thousands with given separator. e.g. 1234 -> "1.234" or "1,234"
String _formatThousands(int n, String sep) {
  final s = n.toString();
  final len = s.length;
  if (len <= 3) return s;
  final buffer = StringBuffer();
  final firstGroupLen = len % 3 == 0 ? 3 : len % 3;
  buffer.write(s.substring(0, firstGroupLen));
  for (int i = firstGroupLen; i < len; i += 3) {
    buffer.write(sep);
    buffer.write(s.substring(i, i + 3));
  }
  return buffer.toString();
}

/// "100", "100.5", "100,50" -> cents. Returns null if the text is not a valid amount.
int? parseEuroToCents(String input) {
  final s = input.trim().replaceAll(',', '.');
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final euros = int.parse(m.group(1)!);
  final fraction = int.parse((m.group(2) ?? '0').padRight(2, '0')); // "5" means 50 cents
  return euros * 100 + fraction;
}

/// Formats cents into currency string.
/// In English: €123.45 (or -€123.45)
/// In German: 123,45 € (or -123,45 €)
String formatCents(int cents, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  final abs = cents.abs();
  final euros = abs ~/ 100;
  final fraction = (abs % 100).toString().padLeft(2, '0');

  if (loc.startsWith('de')) {
    final eurosStr = euros >= 1000 ? _formatThousands(euros, '.') : '$euros';
    return cents < 0 ? '-$eurosStr,$fraction €' : '$eurosStr,$fraction €';
  } else {
    final eurosStr = euros >= 1000 ? _formatThousands(euros, ',') : '$euros';
    return cents < 0 ? '-€$eurosStr.$fraction' : '€$eurosStr.$fraction';
  }
}

/// 5.0 -> "5", 7.5 -> "7.5" (English) or "7,5" (German)
String formatPercent(num d, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  if (d == d.roundToDouble()) return '${d.toInt()}';
  final s = '$d';
  return loc.startsWith('de') ? s.replaceAll('.', ',') : s;
}

/// 10.0 -> "10", 2.5 -> "2.5", 0.125 -> "0.125" (English) or "0,125" (German)
String formatQuantity(num n, [String? locale]) {
  final loc = locale ?? currentAppLocale;
  if (n == n.roundToDouble()) return '${n.toInt()}';
  final s = n.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  return loc.startsWith('de') ? s.replaceAll('.', ',') : s;
}
