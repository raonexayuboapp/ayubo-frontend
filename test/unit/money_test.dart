import 'package:flutter_test/flutter_test.dart';
import 'package:ayubo_customer_app/utils/money.dart';

void main() {
  setUp(() {
    currentAppLocale = 'en';
  });

  group('formatCents', () {
    test('formats positive amounts correctly', () {
      expect(formatCents(0), '€0.00');
      expect(formatCents(5), '€0.05');
      expect(formatCents(50), '€0.50');
      expect(formatCents(100), '€1.00');
      expect(formatCents(150), '€1.50');
      expect(formatCents(12345), '€123.45');
    });

    test('formats negative amounts correctly with minus sign', () {
      expect(formatCents(-5), '-€0.05');
      expect(formatCents(-50), '-€0.50');
      expect(formatCents(-100), '-€1.00');
      expect(formatCents(-150), '-€1.50');
      expect(formatCents(-12345), '-€123.45');
    });

    test('formats zero correctly', () {
      expect(formatCents(0), '€0.00');
    });

    test('formats German currency correctly', () {
      expect(formatCents(0, 'de'), '0,00 €');
      expect(formatCents(12345, 'de'), '123,45 €');
      expect(formatCents(-12345, 'de'), '-123,45 €');
      expect(formatCents(1234567, 'de'), '12.345,67 €');
    });
  });

  group('parseEuroToCents', () {
    test('parses integers and decimals', () {
      expect(parseEuroToCents('100'), 10000);
      expect(parseEuroToCents('100.5'), 10050);
      expect(parseEuroToCents('100,50'), 10050);
      expect(parseEuroToCents('0.05'), 5);
      expect(parseEuroToCents('invalid'), isNull);
    });
  });

  group('formatQuantity & formatPercent', () {
    test('formats quantities correctly', () {
      expect(formatQuantity(10.0), '10');
      expect(formatQuantity(2.5), '2.5');
      expect(formatQuantity(0.125), '0.125');
    });

    test('formats German quantities correctly', () {
      expect(formatQuantity(2.5, 'de'), '2,5');
      expect(formatQuantity(0.125, 'de'), '0,125');
    });

    test('formats percent correctly', () {
      expect(formatPercent(5.0), '5');
      expect(formatPercent(7.5), '7.5');
    });

    test('formats German percent correctly', () {
      expect(formatPercent(5.0, 'de'), '5');
      expect(formatPercent(7.5, 'de'), '7,5');
    });
  });
}
