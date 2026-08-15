import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/models/favorite_item.dart';
import 'package:freshflag/models/grocery_item.dart';

void main() {
  GroceryItem item({String? barcode, String id = 'item-1'}) => GroceryItem(
        id: id,
        name: 'Milk',
        quantity: 2,
        category: 'Dairy',
        barcode: barcode,
        addedDate: DateTime(2026, 8, 15),
        expiryDate: DateTime(2026, 8, 22),
        location: 'Fridge',
        notes: 'Purchase-specific note',
      );

  test('favourite keeps reusable product fields without an expiry date', () {
    final favorite = FavoriteItem.fromGroceryItem(item(barcode: '0123456789012'));
    final map = favorite.toMap();

    expect(favorite.name, 'Milk');
    expect(favorite.quantity, 2);
    expect(favorite.category, 'Dairy');
    expect(favorite.barcode, '0123456789012');
    expect(favorite.location, 'Fridge');
    expect(map.containsKey('expiryDate'), isFalse);
    expect(map.containsKey('notes'), isFalse);
  });

  test('barcode favourites use a deterministic product id', () {
    final first = FavoriteItem.fromGroceryItem(item(barcode: '0123456789012'));
    final second = FavoriteItem.fromGroceryItem(
      item(barcode: '0123456789012', id: 'different-item'),
    );

    expect(first.id, 'barcode-0123456789012');
    expect(second.id, first.id);
  });

  test('manual favourites deduplicate by normalized name and category', () {
    final first = FavoriteItem.fromGroceryItem(item());
    final second = FavoriteItem.fromGroceryItem(item(id: 'different-item'));

    expect(first.id, 'manual-milk%7Cdairy');
    expect(second.id, first.id);
  });
}
