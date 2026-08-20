import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryActivity {
  const InventoryActivity({
    required this.id,
    required this.eventType,
    required this.itemId,
    required this.itemName,
    required this.createdAt,
    this.actorUid,
  });

  final String id;
  final InventoryActivityType eventType;
  final String itemId;
  final String itemName;
  final DateTime? createdAt;
  final String? actorUid;

  String get title => switch (eventType) {
    InventoryActivityType.itemAdded => '$itemName added',
    InventoryActivityType.itemChanged => '$itemName updated',
    InventoryActivityType.itemRemoved => '$itemName removed',
    InventoryActivityType.itemConsumed => '$itemName consumed',
    InventoryActivityType.itemRestored => '$itemName restored',
    InventoryActivityType.unknown => '$itemName changed',
  };

  String get subtitle => switch (eventType) {
    InventoryActivityType.itemAdded => 'Added to household inventory',
    InventoryActivityType.itemChanged => 'Item details changed',
    InventoryActivityType.itemRemoved => 'Removed from household inventory',
    InventoryActivityType.itemConsumed => 'Marked consumed',
    InventoryActivityType.itemRestored => 'Restored to active inventory',
    InventoryActivityType.unknown => 'Household inventory changed',
  };

  factory InventoryActivity.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['createdAt'];
    return InventoryActivity(
      id: doc.id,
      eventType: InventoryActivityType.fromValue(data['eventType']),
      itemId: data['itemId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? 'Item',
      actorUid: data['actorUid'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

enum InventoryActivityType {
  itemAdded,
  itemChanged,
  itemRemoved,
  itemConsumed,
  itemRestored,
  unknown;

  static InventoryActivityType fromValue(Object? value) => switch (value) {
    'item_added' => InventoryActivityType.itemAdded,
    'item_changed' => InventoryActivityType.itemChanged,
    'item_removed' => InventoryActivityType.itemRemoved,
    'item_consumed' => InventoryActivityType.itemConsumed,
    'item_restored' => InventoryActivityType.itemRestored,
    _ => InventoryActivityType.unknown,
  };
}
