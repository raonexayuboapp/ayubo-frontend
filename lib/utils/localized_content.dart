import 'package:flutter/material.dart';

import 'money.dart';

/// Centralized frontend localization and safe fallback utilities for database-backed
/// content and administrative status fields.
///
/// Follows the fallback precedence:
/// 1. Requested / currently active app language (en or de).
/// 2. Primary fallback translation (de or en).
/// 3. Legacy top-level field or established default value.
/// 4. Never displays null, raw map objects, or placeholders.

String resolveAppLocale(BuildContext? context, [String? explicitLocale]) {
  if (explicitLocale != null && explicitLocale.isNotEmpty) {
    return explicitLocale;
  }
  if (context != null) {
    try {
      final loc = Localizations.localeOf(context).languageCode;
      if (loc.isNotEmpty) return loc;
    } catch (_) {}
  }
  return currentAppLocale;
}

/// Returns the localized product name with German/English fallback.
String localizedProductName(
  Map<String, dynamic> product, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final translations = product['translations'];

  if (translations is Map) {
    final curMap = translations[loc];
    if (curMap is Map) {
      final name = curMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }

    final fallbackLang = loc == 'en' ? 'de' : 'en';
    final fbMap = translations[fallbackLang];
    if (fbMap is Map) {
      final name = fbMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
  }

  final topName = product['name']?.toString().trim();
  if (topName != null && topName.isNotEmpty) return topName;

  final slug = product['slug']?.toString().trim();
  if (slug != null && slug.isNotEmpty) return slug;

  return loc == 'de' ? 'Unbenanntes Produkt' : 'Unnamed Product';
}

/// Returns the localized product description with fallback.
String localizedProductDescription(
  Map<String, dynamic> product, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final translations = product['translations'];

  if (translations is Map) {
    final curMap = translations[loc];
    if (curMap is Map) {
      final desc = curMap['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }

    final fallbackLang = loc == 'en' ? 'de' : 'en';
    final fbMap = translations[fallbackLang];
    if (fbMap is Map) {
      final desc = fbMap['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }
  }

  final topDesc = product['description']?.toString().trim();
  if (topDesc != null && topDesc.isNotEmpty) return topDesc;

  return '';
}

/// Returns the localized membership plan name with German/English fallback.
String localizedMembershipPlanName(
  Map<String, dynamic> plan, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final translations = plan['translations'];

  if (translations is Map) {
    final curMap = translations[loc];
    if (curMap is Map) {
      final name = curMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }

    final fallbackLang = loc == 'en' ? 'de' : 'en';
    final fbMap = translations[fallbackLang];
    if (fbMap is Map) {
      final name = fbMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
  }

  final topName = plan['name']?.toString().trim();
  if (topName != null && topName.isNotEmpty) return topName;

  final code = plan['code']?.toString().trim();
  if (code != null && code.isNotEmpty) return code;

  return loc == 'de' ? 'Mitgliedschaftsplan' : 'Membership Plan';
}

/// Returns the localized membership plan description with fallback.
String localizedMembershipPlanDescription(
  Map<String, dynamic> plan, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final translations = plan['translations'];

  if (translations is Map) {
    final curMap = translations[loc];
    if (curMap is Map) {
      final desc = curMap['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }

    final fallbackLang = loc == 'en' ? 'de' : 'en';
    final fbMap = translations[fallbackLang];
    if (fbMap is Map) {
      final desc = fbMap['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }
  }

  final topDesc = plan['description']?.toString().trim();
  if (topDesc != null && topDesc.isNotEmpty) return topDesc;

  return '';
}

/// Returns the localized description for a single membership benefit row.
String localizedBenefitDescription(
  Map<String, dynamic> benefit, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final kind = benefit['kind'] as String?;

  if (kind == 'credit') {
    final cents = benefit['credit_cents'] as int?;
    if (cents != null) {
      return loc == 'de'
          ? '${formatCents(cents, loc)} Einkaufsguthaben'
          : '${formatCents(cents, loc)} shopping credit';
    }
    final top =
        benefit['description_$loc'] ??
        benefit['description_de'] ??
        benefit['description'];
    return top?.toString().trim() ??
        (loc == 'de' ? 'Einkaufsguthaben' : 'Shopping credit');
  }

  if (kind == 'discount') {
    final percent = benefit['discount_percent'] as num?;
    if (percent != null) {
      return loc == 'de'
          ? '${formatPercent(percent, loc)}% Rabatt auf alle Produkte'
          : '${formatPercent(percent, loc)}% discount on all products';
    }
    final top =
        benefit['description_$loc'] ??
        benefit['description_de'] ??
        benefit['description'];
    return top?.toString().trim() ??
        (loc == 'de' ? 'Rabatt auf alle Produkte' : 'Discount on all products');
  }

  // Custom perk or other benefit
  final customDesc = benefit['description_$loc']?.toString().trim();
  if (customDesc != null && customDesc.isNotEmpty) return customDesc;

  final fbDesc = (benefit['description_de'] ?? benefit['description_en'])
      ?.toString()
      .trim();
  if (fbDesc != null && fbDesc.isNotEmpty) return fbDesc;

  final legacyDesc = benefit['description']?.toString().trim();
  if (legacyDesc != null && legacyDesc.isNotEmpty) return legacyDesc;

  return loc == 'de' ? 'Mitgliedervorteil' : 'Membership benefit';
}

/// Returns the localized category name with fallback.
String localizedCategoryName(
  Map<String, dynamic> category, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final translations = category['translations'];

  if (translations is Map) {
    final curMap = translations[loc];
    if (curMap is Map) {
      final name = curMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }

    final fallbackLang = loc == 'en' ? 'de' : 'en';
    final fbMap = translations[fallbackLang];
    if (fbMap is Map) {
      final name = fbMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
  }

  final topName = category['name']?.toString().trim();
  if (topName != null && topName.isNotEmpty) return topName;

  final slug = category['slug']?.toString().trim();
  if (slug != null && slug.isNotEmpty) return slug;

  return loc == 'de' ? 'Kategorie' : 'Category';
}

/// Returns the localized category description with fallback.
String localizedCategoryDescription(
  Map<String, dynamic> category, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final translations = category['translations'];

  if (translations is Map) {
    final curMap = translations[loc];
    if (curMap is Map) {
      final desc = curMap['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }

    final fallbackLang = loc == 'en' ? 'de' : 'en';
    final fbMap = translations[fallbackLang];
    if (fbMap is Map) {
      final desc = fbMap['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }
  }

  final topDesc = category['description']?.toString().trim();
  if (topDesc != null && topDesc.isNotEmpty) return topDesc;

  return '';
}

/// Returns localized label for product status (draft, published, archived).
String localizedProductStatus(
  String status, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final norm = status.trim().toLowerCase();

  if (loc == 'de') {
    switch (norm) {
      case 'published':
        return 'Veröffentlicht';
      case 'archived':
        return 'Archiviert';
      case 'draft':
      default:
        return 'Entwurf';
    }
  }

  switch (norm) {
    case 'published':
      return 'Published';
    case 'archived':
      return 'Archived';
    case 'draft':
    default:
      return 'Draft';
  }
}

/// Returns localized label for user role.
String localizedUserRole(String role, {BuildContext? context, String? locale}) {
  final loc = resolveAppLocale(context, locale);
  final norm = role.trim().toLowerCase();

  if (loc == 'de') {
    return norm == 'admin' ? 'Administrator' : 'Kunde';
  }
  return norm == 'admin' ? 'Admin' : 'Customer';
}

/// Returns localized label for user account active status.
String localizedUserStatus(
  bool isActive, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  if (loc == 'de') {
    return isActive ? 'Aktiviert' : 'Deaktiviert';
  }
  return isActive ? 'Enabled' : 'Disabled';
}

/// Returns localized label for email verification status.
String localizedEmailVerified(
  bool isVerified, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  if (loc == 'de') {
    return isVerified ? 'E-Mail verifiziert' : 'E-Mail unbestätigt';
  }
  return isVerified ? 'Email verified' : 'Email unverified';
}

/// Returns localized label for tax rate status (current, ended, upcoming).
String localizedTaxRateStatus(
  String status, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final norm = status.trim().toLowerCase();

  if (loc == 'de') {
    switch (norm) {
      case 'current':
        return 'Aktuell';
      case 'ended':
        return 'Beendet';
      case 'upcoming':
        return 'Zukünftig';
      default:
        return status;
    }
  }

  switch (norm) {
    case 'current':
      return 'Current';
    case 'ended':
      return 'Ended';
    case 'upcoming':
      return 'Upcoming';
    default:
      return status;
  }
}

/// Returns localized label for stock movement reasons.
String localizedStockReason(
  String reason, {
  BuildContext? context,
  String? locale,
}) {
  final loc = resolveAppLocale(context, locale);
  final norm = reason.trim().toLowerCase();

  if (loc == 'de') {
    switch (norm) {
      case 'receipt':
        return 'Wareneingang';
      case 'adjustment':
        return 'Korrektur';
      case 'stocktake':
        return 'Inventur';
      case 'sale':
        return 'Verkauf';
      default:
        return reason;
    }
  }

  switch (norm) {
    case 'receipt':
      return 'Goods received';
    case 'adjustment':
      return 'Adjustment';
    case 'stocktake':
      return 'Stocktake';
    case 'sale':
      return 'Sale';
    default:
      return reason;
  }
}
