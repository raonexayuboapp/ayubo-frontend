import 'countries.dart';

/// The lines of an address the way a parcel label reads. Works for saved addresses and for order addresses.
List<String> addressLines(Map<String, dynamic> a) {
  String? text(String key) {
    final v = a[key] as String?;
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  return [
    a['recipient'] as String,
    text('company'),
    a['street'] as String,
    text('address_line2'),
    '${a['postal_code']} ${a['city']}',
    text('region'),
    countryName(a['country_code'] as String),
  ].whereType<String>().toList();
}

/// "Hauptstrasse 12, 10115 Berlin"
String addressOneLine(Map<String, dynamic> a) => '${a['street']}, ${a['postal_code']} ${a['city']}';