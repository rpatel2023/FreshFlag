import 'package:hive/hive.dart';

part 'grocery_item.g.dart';

/// Model representing a grocery item in FreshFlag.
///
/// Expiry is a calendar date, not a moment in time. The public field remains a
/// [DateTime] for compatibility with the inherited UI/Hive adapter, but it is
/// normalized to local midnight and serialized as `YYYY-MM-DD`.
@HiveType(typeId: 1)
class GroceryItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int quantity;

  @HiveField(3)
  String category;

  @HiveField(4)
  String? barcode;

  @HiveField(5)
  DateTime addedDate;

  @HiveField(6)
  DateTime expiryDate;

  @HiveField(7)
  String? imageUrl;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  bool isConsumed;

  GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
    this.barcode,
    required this.addedDate,
    required DateTime expiryDate,
    this.imageUrl,
    this.notes,
    this.isConsumed = false,
  }) : expiryDate = _dateOnly(expiryDate);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'category': category,
      'barcode': barcode,
      'addedDate': addedDate.toIso8601String(),
      'expiryDate': _formatDateOnly(expiryDate),
      'imageUrl': imageUrl,
      'notes': notes,
      'isConsumed': isConsumed,
    };
  }

  factory GroceryItem.fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      category: map['category'] as String,
      barcode: map['barcode'] as String?,
      addedDate: DateTime.parse(map['addedDate'] as String),
      // DateTime.parse also accepts inherited full ISO timestamp records. The
      // constructor normalizes both old and new representations to a date.
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      imageUrl: map['imageUrl'] as String?,
      notes: map['notes'] as String?,
      isConsumed: map['isConsumed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory GroceryItem.fromJson(Map<String, dynamic> json) =>
      GroceryItem.fromMap(json);

  GroceryItem copyWith({
    String? id,
    String? name,
    int? quantity,
    String? category,
    String? barcode,
    DateTime? addedDate,
    DateTime? expiryDate,
    String? imageUrl,
    String? notes,
    bool? isConsumed,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      addedDate: addedDate ?? this.addedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      isConsumed: isConsumed ?? this.isConsumed,
    );
  }

  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = _dateOnly(now);
    return expiryDate.difference(today).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;

  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;

  ExpiryStatus get expiryStatus {
    if (isExpired) return ExpiryStatus.expired;
    if (isExpiringSoon) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  String toString() {
    return 'GroceryItem(id: $id, name: $name, quantity: $quantity, category: $category, '
        'barcode: $barcode, addedDate: $addedDate, expiryDate: $expiryDate, '
        'imageUrl: $imageUrl, notes: $notes, isConsumed: $isConsumed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryItem &&
        other.id == id &&
        other.name == name &&
        other.quantity == quantity &&
        other.category == category &&
        other.barcode == barcode &&
        other.addedDate == addedDate &&
        other.expiryDate == expiryDate &&
        other.imageUrl == imageUrl &&
        other.notes == notes &&
        other.isConsumed == isConsumed;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        quantity,
        category,
        barcode,
        addedDate,
        expiryDate,
        imageUrl,
        notes,
        isConsumed,
      );
}

enum ExpiryStatus {
  fresh,
  expiringSoon,
  expired,
}
