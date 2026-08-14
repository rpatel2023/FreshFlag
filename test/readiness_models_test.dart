import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/models/grocery_item.dart';
import 'package:freshflag/models/household.dart';
import 'package:freshflag/models/product_lookup_result.dart';

void main() {
  group('MVP readiness model persistence', () {
    test('inventory preserves brand and location metadata', () {
      final item = GroceryItem(
        id: 'item-1',
        name: 'Milk',
        quantity: 1,
        category: 'Dairy',
        barcode: '066721000123',
        brand: 'Natrel',
        addedDate: DateTime(2026, 8, 14),
        expiryDate: DateTime(2026, 8, 20),
        location: 'Fridge',
        imageUrl: 'https://example.test/milk.jpg',
      );

      final restored = GroceryItem.fromMap(item.toMap());
      expect(restored, item);
      expect(restored.brand, 'Natrel');
      expect(restored.location, 'Fridge');
    });

    test('household member display name round-trips', () {
      final member = HouseholdMember(
        uid: 'member-123456789',
        role: HouseholdRole.member,
        joinedAt: DateTime.utc(2026, 8, 14),
        displayName: 'Raj',
      );

      final restored = HouseholdMember.fromMap(member.uid, member.toMap());
      expect(restored.displayName, 'Raj');
      expect(restored.displayLabel, 'Raj');
    });

    test('household member has a safe fallback display label', () {
      final member = HouseholdMember(
        uid: 'member-123456789',
        role: HouseholdRole.member,
        joinedAt: DateTime.utc(2026, 8, 14),
      );

      expect(member.displayLabel, 'Member member-1');
    });
  });

  group('Product lookup metadata', () {
    test('parses cached FreshFlag product metadata', () {
      final product = ProductLookupResult.fromFreshFlagProduct({
        'barcode': '3017620422003',
        'name': 'Hazelnut Spread',
        'brand': 'Ferrero',
        'imageUrl': 'https://example.test/front.jpg',
        'quantityLabel': '400 g',
      });

      expect(product.barcode, '3017620422003');
      expect(product.name, 'Hazelnut Spread');
      expect(product.brand, 'Ferrero');
      expect(product.imageUrl, 'https://example.test/front.jpg');
      expect(product.quantityLabel, '400 g');
    });

    test('parses brand and image from Open Food Facts', () {
      final product = ProductLookupResult.fromOpenFoodFactsProduct(
        '12345678',
        {
          'product_name': 'Tomato Sauce',
          'brands': 'Example Foods',
          'image_front_small_url': 'https://example.test/tomato.jpg',
        },
      );

      expect(product.brand, 'Example Foods');
      expect(product.imageUrl, 'https://example.test/tomato.jpg');
    });
  });
}
