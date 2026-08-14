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
    this.householdId,
    this.createdByUid,
    this.updatedByUid,
    this.updatedAt,
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
  final String? householdId;
  final String? createdByUid;
  final String? updatedByUid;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
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
        'householdId': householdId,
        'createdByUid': createdByUid,
        'updatedByUid': updatedByUid,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory GroceryItem.fromMap(Map<String, dynamic> map) => GroceryItem(
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
        householdId: map['householdId'] as String?,
        createdByUid: map['createdByUid'] as String?,
        updatedByUid: map['updatedByUid'] as String?,
        updatedAt: map['updatedAt'] == null
            ? null
            : DateTime.parse(map['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => toMap();
  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem.fromMap(json);

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
    String? householdId,
    String? createdByUid,
    String? updatedByUid,
    DateTime? updatedAt,
  }) => GroceryItem(
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
        householdId: householdId ?? this.householdId,
        createdByUid: createdByUid ?? this.createdByUid,
        updatedByUid: updatedByUid ?? this.updatedByUid,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  int get daysUntilExpiry {
    final today = normalizeDateOnly(DateTime.now());
    return expiryDate.difference(today).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;
  ExpiryStatus get expiryStatus => isExpired
      ? ExpiryStatus.expired
      : isExpiringSoon
          ? ExpiryStatus.expiringSoon
          : ExpiryStatus.fresh;

  static DateTime normalizeDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
  static DateTime parseDateOnly(String value) => normalizeDateOnly(DateTime.parse(value));
  static String formatDateOnly(DateTime value) {
    final date = normalizeDateOnly(value);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  bool operator ==(Object other) => identical(this, other) ||
      other is GroceryItem &&
          other.id == id &&
          other.name == name &&
          other.quantity == quantity &&
          other.category == category &&
          other.barcode == barcode &&
          other.addedDate == addedDate &&
          other.expiryDate == expiryDate &&
          other.imageUrl == imageUrl &&
          other.notes == notes &&
          other.isConsumed == isConsumed &&
          other.householdId == householdId &&
          other.createdByUid == createdByUid &&
          other.updatedByUid == updatedByUid &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id, name, quantity, category, barcode, addedDate, expiryDate, imageUrl,
        notes, isConsumed, householdId, createdByUid, updatedByUid, updatedAt,
      );
}

enum ExpiryStatus { fresh, expiringSoon, expired }
