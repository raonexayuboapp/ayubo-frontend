import 'package:ayubo_customer_app/l10n/app_localizations.dart';
import 'package:ayubo_customer_app/theme/app_theme.dart';
import 'package:ayubo_customer_app/widgets/home/home_bestsellers_section.dart';
import 'package:ayubo_customer_app/widgets/home/home_family_promo_section.dart';
import 'package:ayubo_customer_app/widgets/home/home_shop_experience_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget createTestWrapper({
  required Widget child,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    locale: locale,
    themeMode: themeMode,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('de'),
    ],
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeBestSellersSection', () {
    testWidgets('renders empty as SizedBox.shrink when not loading or error', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          child: HomeBestSellersSection(
            products: const [],
            user: null,
            onRetry: () {},
            onViewAll: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders section header and products list in English and German', (tester) async {
      final sampleProducts = [
        {
          'id': 1,
          'name': 'Organic Ceylon Cinnamon',
          'slug': 'organic-ceylon-cinnamon',
          'price_cents': 1250,
          'original_price_cents': null,
          'is_discounted': false,
          'discount_percentage': 0,
          'is_favourite': false,
          'image_url': null,
          'variant_count': 1,
        },
      ];

      bool viewAllCalled = false;

      // English
      await tester.pumpWidget(
        createTestWrapper(
          locale: const Locale('en'),
          child: HomeBestSellersSection(
            products: sampleProducts,
            user: null,
            onRetry: () {},
            onViewAll: () => viewAllCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Curated Bestsellers'), findsOneWidget);
      expect(find.text('Customer favorites & organic essentials'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      await tester.tap(find.text('View All'));
      expect(viewAllCalled, isTrue);

      // German
      await tester.pumpWidget(
        createTestWrapper(
          locale: const Locale('de'),
          child: HomeBestSellersSection(
            products: sampleProducts,
            user: null,
            onRetry: () {},
            onViewAll: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beliebteste Produkte'), findsOneWidget);
      expect(find.text('Beliebte Kundenfavoriten & Bio-Klassiker'), findsOneWidget);
      expect(find.text('Alle ansehen'), findsOneWidget);
    });

    testWidgets('renders error state with retry button', (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        createTestWrapper(
          child: HomeBestSellersSection(
            products: const [],
            user: null,
            error: 'Failed to fetch items',
            onRetry: () => retryCalled = true,
            onViewAll: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch items'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });
  });

  group('HomeFamilyPromoSection', () {
    testWidgets('renders benefits and triggers onExplore callback in English', (tester) async {
      bool exploreCalled = false;

      await tester.pumpWidget(
        createTestWrapper(
          locale: const Locale('en'),
          child: HomeFamilyPromoSection(
            user: null,
            membership: null,
            onExplore: () => exploreCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AYUBO FAMILY'), findsOneWidget);
      expect(find.text('Unlock Exclusive Wellness Privileges'), findsOneWidget);
      expect(find.text('100% shopping credit back on membership'), findsOneWidget);
      expect(find.text('Exclusive member discounts on select organics'), findsOneWidget);
      expect(find.text('Pure Ceylon organic wellness privileges'), findsOneWidget);
      expect(find.text('Explore Ayubo Family'), findsOneWidget);

      await tester.tap(find.text('Explore Ayubo Family'));
      expect(exploreCalled, isTrue);
    });

    testWidgets('renders in German correctly', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          locale: const Locale('de'),
          child: HomeFamilyPromoSection(
            user: const {'id': 1},
            membership: null,
            onExplore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AYUBO FAMILIE'), findsOneWidget);
      expect(find.text('Exklusive Vorteile für Ihr Wohlbefinden'), findsOneWidget);
      expect(find.text('100% Einkaufsguthaben auf Ihre Mitgliedschaft'), findsOneWidget);
      expect(find.text('Exklusive Rabatte auf ausgewählte Bio-Produkte'), findsOneWidget);
      expect(find.text('Reine Ceylon-Bio- und Ayurveda-Vorteile'), findsOneWidget);
      expect(find.text('Ayubo Familie entdecken'), findsOneWidget);
    });

    testWidgets('renders cleanly in dark mode without overflow', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          themeMode: ThemeMode.dark,
          child: HomeFamilyPromoSection(
            user: null,
            membership: null,
            onExplore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Explore Ayubo Family'), findsOneWidget);
    });
  });

  group('HomeShopExperienceSection', () {
    testWidgets('renders shop information and triggers explore in English', (tester) async {
      bool exploreProductsCalled = false;

      await tester.pumpWidget(
        createTestWrapper(
          locale: const Locale('en'),
          child: HomeShopExperienceSection(
            user: null,
            onExploreProducts: () => exploreProductsCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OUR PHYSICAL BOUTIQUE'), findsOneWidget);
      expect(find.text('Experience Ayubo Organics'), findsOneWidget);
      expect(find.text('100% Certified Organic'), findsOneWidget);
      expect(find.text('Direct Fair Trade'), findsOneWidget);
      expect(find.text('Authentic Ceylon Heritage'), findsOneWidget);
      expect(find.text('Explore In-Store Collection'), findsOneWidget);

      await tester.tap(find.text('Explore In-Store Collection'));
      expect(exploreProductsCalled, isTrue);
    });

    testWidgets('renders in German correctly', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          locale: const Locale('de'),
          child: HomeShopExperienceSection(
            user: null,
            onExploreProducts: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNSERE BOUTIQUE'), findsOneWidget);
      expect(find.text('Ayubo Organics erleben'), findsOneWidget);
      expect(find.text('100% Bio-zertifiziert'), findsOneWidget);
      expect(find.text('Direkter fairer Handel'), findsOneWidget);
      expect(find.text('Authentische Ceylon-Tradition'), findsOneWidget);
      expect(find.text('Boutique-Sortiment entdecken'), findsOneWidget);
    });

    testWidgets('renders cleanly in dark mode without overflow', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          themeMode: ThemeMode.dark,
          child: HomeShopExperienceSection(
            user: null,
            onExploreProducts: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Explore In-Store Collection'), findsOneWidget);
    });
  });
}
