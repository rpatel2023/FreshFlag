import 'package:flutter_test/flutter_test.dart';
import 'package:stayfresh/models/grocery_item.dart';

void main() {
  group('GroceryItem persistence', () {
    test('round-trips all persisted fields', () {
      final item = GroceryItem(
        id: 'item-1',
        name: 'Milk',
        quantity: 2,
        category: 'Dairy',
        barcode: '0123456789012',
        addedDate: DateTime(2026, 8, 14),
        expiryDate: DateTime(2026, 8, 20),
        imageUrl: 'https://example.test/milk.jpg',
        notes: 'Use first',
        isConsumed: true,
      );

      final restored = GroceryItem.fromMap(item.toMap());

      expect(restored, item);
      expect(restored.notes, 'Use first');
      expect(restored.isConsumed, isTrue);
      expect(restored.barcode, '0123456789012');
    });

    test('supports legacy records missing optional state fields', () {
      final restored = GroceryItem.fromMap({
        'id': 'legacy-1',
        'name': 'Bread',
        'quantity': 1,
        'category': 'Bakery',
        'barcode': null,
        'addedDate': '2026-08-14T00:00:00.000',
        'expiryDate': '2026-08-17T00:00:00.000',
        'imageUrl': null,
      });

      expect(restored.notes, isNull);
      expect(restored.isConsumed, isFalse);
    });

    test('normalizes expiry calculations to calendar days', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final item = GroceryItem(
        id: 'date-1',
        name: 'Yogurt',
        quantity: 1,
        category: 'Dairy',
        addedDate: today,
        expiryDate: today.add(const Duration(days: 3, hours: 18)),
      );

      expect(item.daysUntilExpiry, 3);
      expect(item.isExpiringSoon, isTrue);
    });
  });
}
