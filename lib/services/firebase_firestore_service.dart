import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grocery_item.dart';
import 'firebase_auth_service.dart';

/// Firestore access for the authenticated user's Phase 1 inventory.
///
/// Collection structure:
/// `users/{uid}/groceryItems/{itemId}`
class FirebaseFirestoreService {
  static final FirebaseFirestoreService _instance =
      FirebaseFirestoreService._internal();
  static FirebaseFirestoreService get instance => _instance;

  FirebaseFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  CollectionReference<Map<String, dynamic>> get _items {
    final uid = _auth.currentUserId;
    if (uid == null) throw StateError('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('groceryItems');
  }

  Future<String> addGroceryItem(GroceryItem item) async {
    try {
      await _items.doc(item.id).set(item.toMap());
      return item.id;
    } catch (e) {
      throw Exception('Failed to add grocery item: $e');
    }
  }

  Future<void> updateGroceryItem(GroceryItem item) async {
    try {
      await _items.doc(item.id).set(item.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update grocery item: $e');
    }
  }

  Future<void> deleteGroceryItem(String itemId) async {
    try {
      await _items.doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete grocery item: $e');
    }
  }

  Future<GroceryItem?> getGroceryItem(String itemId) async {
    try {
      final doc = await _items.doc(itemId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return GroceryItem.fromMap({...data, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to get grocery item: $e');
    }
  }

  Future<List<GroceryItem>> getAllGroceryItems() async {
    try {
      final snapshot = await _items.orderBy('expiryDate').get();
      return _fromSnapshot(snapshot);
    } catch (e) {
      throw Exception('Failed to get grocery items: $e');
    }
  }

  Future<List<GroceryItem>> getGroceryItemsByCategory(String category) async {
    try {
      final snapshot = await _items
          .where('category', isEqualTo: category)
          .orderBy('expiryDate')
          .get();
      return _fromSnapshot(snapshot);
    } catch (e) {
      throw Exception('Failed to get grocery items by category: $e');
    }
  }

  Future<List<GroceryItem>> getExpiredGroceryItems() async {
    try {
      final today = GroceryItem.formatDateOnly(DateTime.now());
      final snapshot = await _items
          .where('expiryDate', isLessThan: today)
          .orderBy('expiryDate')
          .get();
      return _fromSnapshot(snapshot);
    } catch (e) {
      throw Exception('Failed to get expired grocery items: $e');
    }
  }

  Future<List<GroceryItem>> getGroceryItemsExpiringSoon({int days = 3}) async {
    try {
      final now = DateTime.now();
      final today = GroceryItem.formatDateOnly(now);
      final through = GroceryItem.formatDateOnly(now.add(Duration(days: days)));
      final snapshot = await _items
          .where('expiryDate', isGreaterThanOrEqualTo: today)
          .where('expiryDate', isLessThanOrEqualTo: through)
          .orderBy('expiryDate')
          .get();
      return _fromSnapshot(snapshot);
    } catch (e) {
      throw Exception('Failed to get grocery items expiring soon: $e');
    }
  }

  Stream<List<GroceryItem>> streamGroceryItems() {
    return _items.orderBy('expiryDate').snapshots().map(_fromSnapshot);
  }

  Future<List<GroceryItem>> searchGroceryItems(String query) async {
    try {
      final allItems = _fromSnapshot(await _items.get());
      final normalized = query.trim().toLowerCase();
      return allItems.where((item) {
        return item.name.toLowerCase().contains(normalized) ||
            item.category.toLowerCase().contains(normalized) ||
            (item.barcode?.toLowerCase().contains(normalized) ?? false);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search grocery items: $e');
    }
  }

  Future<void> batchDeleteGroceryItems(List<String> itemIds) async {
    try {
      final batch = _firestore.batch();
      for (final id in itemIds) {
        batch.delete(_items.doc(id));
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch delete grocery items: $e');
    }
  }

  Future<Map<String, int>> getItemCountByCategory() async {
    try {
      final snapshot = await _items.get();
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'Other';
        counts[category] = (counts[category] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      throw Exception('Failed to get item count by category: $e');
    }
  }

  Future<int> cleanupExpiredItems({int daysAfterExpiry = 30}) async {
    try {
      final cutoff = GroceryItem.formatDateOnly(
        DateTime.now().subtract(Duration(days: daysAfterExpiry)),
      );
      final snapshot = await _items
          .where('expiryDate', isLessThan: cutoff)
          .get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to cleanup expired items: $e');
    }
  }

  List<GroceryItem> _fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }
}
