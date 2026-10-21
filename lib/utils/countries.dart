/// Countries offered in the address form. The server accepts any two-letter code; this list only gives
/// instant feedback and a readable name. Postal rules mirror the server's (which is the authority).
class Country {
  final String code;
  final String name;
  final RegExp? postal;
  final String? example;

  Country(this.code, this.name, [this.postal, this.example]);
}

final List<Country> countries = [
  Country('DE', 'Germany', RegExp(r'^\d{5}$'), '10115'),
  Country('AT', 'Austria', RegExp(r'^\d{4}$'), '1010'),
  Country('BE', 'Belgium', RegExp(r'^\d{4}$'), '1000'),
  Country('DK', 'Denmark', RegExp(r'^\d{4}$'), '1050'),
  Country('ES', 'Spain', RegExp(r'^\d{5}$'), '28001'),
  Country('FR', 'France', RegExp(r'^\d{5}$'), '75001'),
  Country('GB', 'United Kingdom', RegExp(r'^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$'), 'SW1A 1AA'),
  Country('IT', 'Italy', RegExp(r'^\d{5}$'), '00100'),
  Country('LI', 'Liechtenstein', RegExp(r'^\d{4}$'), '9490'),
  Country('LK', 'Sri Lanka', RegExp(r'^\d{5}$'), '10100'),
  Country('LU', 'Luxembourg', RegExp(r'^\d{4}$'), '1111'),
  Country('NL', 'Netherlands', RegExp(r'^\d{4} ?[A-Z]{2}$'), '1012 AB'),
  Country('PL', 'Poland', RegExp(r'^\d{2}-\d{3}$'), '00-001'),
  Country('CH', 'Switzerland', RegExp(r'^\d{4}$'), '8001'),
];

Country? countryByCode(String code) {
  for (final c in countries) {
    if (c.code == code) return c;
  }
  return null;
}

String countryName(String code) => countryByCode(code)?.name ?? code;

/// Upper-case, with spaces collapsed: the same normalisation as the server.
String normalizePostal(String? v) => (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

final RegExp genericPostal = RegExp(r'^[A-Z0-9][A-Z0-9 -]{1,18}[A-Z0-9]$');