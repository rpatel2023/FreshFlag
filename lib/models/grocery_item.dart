/// Grocery inventory item persisted in Firestore.
///
/// Expiry is a calendar date. It is normalized to local midnight in memory and
/// serialized as `YYYY-MM-DD` so timezone/time-of-day cannot change which day
/// the food is considered to expire.
class GroceryItem {
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
  }) : expiryDate = normalizeDateOnly(expiryDate);

  final String id;
  final String name;
  final int quantity;
  final String category;
  final String? barcode;
  final DateTime addedDate;
  final DateTime expiryDate;
  final String? imageUrl;
  final String? notes;
  final bool isConsumed;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'category': category,
      'barcode': barcode,
      'addedDate': addedDate.toIso8601String(),
      'expiryDate': formatDateOnly(expiryDate),
      'imageUrl': imageUrl,
      'notes': notes,
      'isConsumed': isConsumed,
    };
  }

  factory GroceryItem.fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: (map['quantity'] as num).toInt(),
      category: map['category'] as String,
      barcode: map['barcode'] as String?,
      addedDate: DateTime.parse(map['addedDate'] as String),
      expiryDate: parseDateOnly(map['expiryDate'] as String),
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
    final today = normalizeDateOnly(now);
    return expiryDate.difference(today).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;

  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;

  ExpiryStatus get expiryStatus {
    if (isExpired) return ExpiryStatus.expired;
    if (isExpiringSoon) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  static DateTime normalizeDateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Accepts current `YYYY-MM-DD` values and inherited full ISO timestamps.
  static DateTime parseDateOnly(String value) {
    final parsed = DateTime.parse(value);
    return normalizeDateOnly(parsed);
  }

  static String formatDateOnly(DateTime value) {
    final date = normalizeDateOnly(value);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  String toString() {
    return 'GroceryItem(id: $id, name: $name, quantity: $quantity, '
        'category: $category, barcode: $barcode, addedDate: $addedDate, '
        'expiryDate: ${formatDateOnly(expiryDate)}, imageUrl: $imageUrl, '
        'notes: $notes, isConsumed: $isConsumed)';
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

enum ExpiryStatus { fresh, expiringSoon, expired }
