import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen product separation logic', () {
    test('best sellers, new arrivals, and collection products never duplicate', () {
      final newestList = [
        {'id': 10, 'name': 'Tea 10'},
        {'id': 9, 'name': 'Tea 9'},
        {'id': 8, 'name': 'Tea 8'},
        {'id': 7, 'name': 'Tea 7'},
        {'id': 6, 'name': 'Tea 6'},
        {'id': 5, 'name': 'Tea 5'},
        {'id': 4, 'name': 'Tea 4'},
      ];

      final nameList = [
        {'id': 1, 'name': 'Ceylon Cinnamon'},
        {'id': 2, 'name': 'Coconut Oil'},
        {'id': 5, 'name': 'Tea 5'},
        {'id': 6, 'name': 'Tea 6'},
        {'id': 8, 'name': 'Tea 8'},
        {'id': 11, 'name': 'Vanilla Bean'},
        {'id': 12, 'name': 'Wild Honey'},
      ];

      final bestSellers = nameList.take(6).toList();
      final bestSellerIds = bestSellers.map((p) => p['id']).toSet();

      final newArrivals = newestList
          .where((p) => !bestSellerIds.contains(p['id']))
          .take(6)
          .toList();
      final arrivalIds = newArrivals.map((p) => p['id']).toSet();

      final collection = nameList
          .where((p) => !bestSellerIds.contains(p['id']) && !arrivalIds.contains(p['id']))
          .take(8)
          .toList();

      expect(bestSellers.length, 6);
      expect(newArrivals.any((p) => bestSellerIds.contains(p['id'])), isFalse);
      expect(collection.any((p) => bestSellerIds.contains(p['id'])), isFalse);
      expect(collection.any((p) => arrivalIds.contains(p['id'])), isFalse);
    });

    test('when store has few products, sections do not duplicate', () {
      final newestList = [
        {'id': 1, 'name': 'Tea 1'},
        {'id': 2, 'name': 'Tea 2'},
      ];

      final nameList = [
        {'id': 1, 'name': 'Tea 1'},
        {'id': 2, 'name': 'Tea 2'},
      ];

      final bestSellers = nameList.take(6).toList();
      final bestSellerIds = bestSellers.map((p) => p['id']).toSet();

      final newArrivals = newestList
          .where((p) => !bestSellerIds.contains(p['id']))
          .take(6)
          .toList();
      final arrivalIds = newArrivals.map((p) => p['id']).toSet();

      final collection = nameList
          .where((p) => !bestSellerIds.contains(p['id']) && !arrivalIds.contains(p['id']))
          .take(8)
          .toList();

      expect(bestSellers.length, 2);
      expect(newArrivals, isEmpty);
      expect(collection, isEmpty);
    });

    test('guest state detection works with null and empty maps', () {
      bool isGuest(Map<String, dynamic>? user) =>
          user == null || user.isEmpty || user['id'] == null;

      expect(isGuest(null), isTrue);
      expect(isGuest(const {}), isTrue);
      expect(isGuest({'role': 'guest'}), isTrue);
      expect(isGuest({'id': 12, 'name': 'John'}), isFalse);
    });
  });
}
