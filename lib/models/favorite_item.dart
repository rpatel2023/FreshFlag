import 'grocery_item.dart';

class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.barcode,
    this.location,
    this.sourceItemId,
  });

  final String id;
  final String name;
  final int quantity;
  final String category;
  final String? barcode;
  final String? location;
  final String? sourceItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FavoriteItem.fromGroceryItem(GroceryItem item) {
    final barcode = item.barcode?.trim();
    final now = DateTime.now().toUtc();
    return FavoriteItem(
      id: idForItem(item),
      name: item.name.trim(),
      quantity: item.quantity,
      category: item.category,
      barcode: barcode == null || barcode.isEmpty ? null : barcode,
      location: _clean(item.location),
      sourceItemId: item.id,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String idForItem(GroceryItem item) {
    final barcode = item.barcode?.trim();
    return barcode != null && barcode.isNotEmpty
        ? 'barcode-$barcode'
        : 'item-${item.id}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'category': category,
        'barcode': barcode,
        'location': location,
        'sourceItemId': sourceItemId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FavoriteItem.fromMap(String id, Map<String, dynamic> map) {
    return FavoriteItem(
      id: id,
      name: map['name'] as String? ?? 'Item',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      category: map['category'] as String? ?? 'Other',
      barcode: map['barcode'] as String?,
      location: map['location'] as String?,
      sourceItemId: map['sourceItemId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  bool matches(GroceryItem item) {
    final itemBarcode = item.barcode?.trim();
    if (barcode != null && itemBarcode != null && barcode == itemBarcode) {
      return true;
    }
    if (sourceItemId == item.id) return true;
    return name.trim().toLowerCase() == item.name.trim().toLowerCase() &&
        category.trim().toLowerCase() == item.category.trim().toLowerCase();
  }

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
