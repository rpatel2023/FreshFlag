import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_item.dart';
import 'firebase_auth_service.dart';

/// Service for handling Firestore database operations.
///
/// All grocery operations are scoped to the currently authenticated user.
/// Collection structure:
/// - users/{userId}/groceryItems/{itemId}
class FirebaseFirestoreService {
  static final FirebaseFirestoreService _instance =
      FirebaseFirestoreService._internal();
  static FirebaseFirestoreService get instance => _instance;

  FirebaseFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  CollectionReference<Map<String, dynamic>> get _groceryItemsCollection {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(userId).collection('groceryItems');
  }

  /// Add a grocery item using the app's item ID as the Firestore document ID.
  ///
  /// Keeping these IDs identical is required so subsequent update/delete
  /// operations target the document that was actually created.
  Future<String> addGroceryItem(GroceryItem item) async {
    try {
      await _groceryItemsCollection.doc(item.id).set(item.toMap());
      return item.id;
    } catch (e) {
      throw Exception('Failed to add grocery item: $e');
    }
  }

  Future<void> updateGroceryItem(GroceryItem item) async {
    try {
      await _groceryItemsCollection.doc(item.id).update(item.toMap());
    } catch (e) {
      throw Exception('Failed to update grocery item: $e');
    }
  }

  Future<void> deleteGroceryItem(String itemId) async {
    try {
      await _groceryItemsCollection.doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete grocery item: $e');
    }
  }

  Future<GroceryItem?> getGroceryItem(String itemId) async {
    try {
      final doc = await _groceryItemsCollection.doc(itemId).get();
      if (doc.exists && doc.data() != null) {
        return GroceryItem.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get grocery item: $e');
    }
  }

  Future<List<GroceryItem>> getAllGroceryItems() async {
    try {
      final querySnapshot = await _groceryItemsCollection
          .orderBy('expiryDate', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get grocery items: $e');
    }
  }

  Future<List<GroceryItem>> getGroceryItemsByCategory(String category) async {
    try {
      final querySnapshot = await _groceryItemsCollection
          .where('category', isEqualTo: category)
          .orderBy('expiryDate', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get grocery items by category: $e');
    }
  }

  Future<List<GroceryItem>> getExpiredGroceryItems() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _groceryItemsCollection
          .where('expiryDate', isLessThan: now.toIso8601String())
          .orderBy('expiryDate', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get expired grocery items: $e');
    }
  }

  Future<List<GroceryItem>> getGroceryItemsExpiringSoon({int days = 3}) async {
    try {
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: days));

      final querySnapshot = await _groceryItemsCollection
          .where('expiryDate', isGreaterThanOrEqualTo: now.toIso8601String())
          .where('expiryDate', isLessThanOrEqualTo: futureDate.toIso8601String())
          .orderBy('expiryDate', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get grocery items expiring soon: $e');
    }
  }

  Stream<List<GroceryItem>> streamGroceryItems() {
    return _groceryItemsCollection
        .orderBy('expiryDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<List<GroceryItem>> searchGroceryItems(String query) async {
    try {
      final querySnapshot = await _groceryItemsCollection.get();
      final allItems = querySnapshot.docs
          .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      final searchQuery = query.toLowerCase();
      return allItems.where((item) {
        return item.name.toLowerCase().contains(searchQuery) ||
            item.category.toLowerCase().contains(searchQuery) ||
            (item.barcode?.contains(searchQuery) ?? false);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search grocery items: $e');
    }
  }

  Future<void> batchDeleteGroceryItems(List<String> itemIds) async {
    try {
      final batch = _firestore.batch();
      for (final itemId in itemIds) {
        batch.delete(_groceryItemsCollection.doc(itemId));
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch delete grocery items: $e');
    }
  }

  Future<Map<String, int>> getItemCountByCategory() async {
    try {
      final querySnapshot = await _groceryItemsCollection.get();
      final Map<String, int> categoryCounts = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'Other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      return categoryCounts;
    } catch (e) {
      throw Exception('Failed to get item count by category: $e');
    }
  }

  Future<int> cleanupExpiredItems({int daysAfterExpiry = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysAfterExpiry));
      final querySnapshot = await _groceryItemsCollection
          .where('expiryDate', isLessThan: cutoffDate.toIso8601String())
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to cleanup expired items: $e');
    }
  }
}
