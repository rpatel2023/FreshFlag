import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/models/grocery_item.dart';
import 'package:freshflag/models/product_lookup_result.dart';

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

      final map = item.toMap();
      final restored = GroceryItem.fromMap(map);

      expect(map['expiryDate'], '2026-08-20');
      expect(restored, item);
      expect(restored.notes, 'Use first');
      expect(restored.isConsumed, isTrue);
      expect(restored.barcode, '0123456789012');
    });

    test('supports legacy timestamp expiry records and normalizes to date-only', () {
      final restored = GroceryItem.fromMap({
        'id': 'legacy-1',
        'name': 'Bread',
        'quantity': 1,
        'category': 'Bakery',
        'barcode': null,
        'addedDate': '2026-08-14T12:34:56.000',
        'expiryDate': '2026-08-17T21:15:00.000',
        'imageUrl': null,
      });

      expect(restored.expiryDate, DateTime(2026, 8, 17));
      expect(restored.toMap()['expiryDate'], '2026-08-17');
      expect(restored.notes, isNull);
      expect(restored.isConsumed, isFalse);
    });

    test('normalizes constructor expiry values to calendar dates', () {
      final item = GroceryItem(
        id: 'date-only-1',
        name: 'Yogurt',
        quantity: 1,
        category: 'Dairy',
        addedDate: DateTime(2026, 8, 14, 18, 30),
        expiryDate: DateTime(2026, 8, 20, 23, 59),
      );

      expect(item.expiryDate, DateTime(2026, 8, 20));
      expect(item.toMap()['expiryDate'], '2026-08-20');
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

  group('ProductLookupResult', () {
    test('parses the Open Food Facts fields FreshFlag needs', () {
      final product = ProductLookupResult.fromOpenFoodFactsProduct(
        '3017620422003',
        {
          'product_name': 'Hazelnut Spread',
          'quantity': '400 g',
        },
      );

      expect(product.barcode, '3017620422003');
      expect(product.name, 'Hazelnut Spread');
      expect(product.quantityLabel, '400 g');
    });

    test('falls back to a generic product name', () {
      final product = ProductLookupResult.fromOpenFoodFactsProduct(
        '12345678',
        {
          'product_name': '   ',
          'generic_name': 'Tomato sauce',
        },
      );

      expect(product.name, 'Tomato sauce');
      expect(product.quantityLabel, isNull);
    });

    test('rejects records without a usable display name', () {
      expect(
        () => ProductLookupResult.fromOpenFoodFactsProduct(
          '12345678',
          {'quantity': '500 g'},
        ),
        throwsFormatException,
      );
    });
  });
}
