import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grocery_item.dart';
import '../models/product_lookup_result.dart';

/// Firestore access for the currently selected household inventory.
class FirebaseFirestoreService {
  static final FirebaseFirestoreService _instance =
      FirebaseFirestoreService._internal();
  static FirebaseFirestoreService get instance => _instance;

  FirebaseFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _householdId;

  void setHousehold(String? householdId) => _householdId = householdId;

  CollectionReference<Map<String, dynamic>> get _items {
    final householdId = _householdId;
    if (householdId == null) throw StateError('No household selected');
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('items');
  }

  CollectionReference<Map<String, dynamic>> get _categories {
    final householdId = _householdId;
    if (householdId == null) throw StateError('No household selected');
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories');
  }

  CollectionReference<Map<String, dynamic>> get _productCache {
    final householdId = _householdId;
    if (householdId == null) throw StateError('No household selected');
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('productCache');
  }

  Future<String> addGroceryItem(GroceryItem item) async {
    await _items.doc(item.id).set(item.toMap());
    return item.id;
  }

  Future<void> updateGroceryItem(GroceryItem item) =>
      _items.doc(item.id).set(item.toMap(), SetOptions(merge: true));

  Future<void> deleteGroceryItem(String itemId) => _items.doc(itemId).delete();

  Future<GroceryItem?> getGroceryItem(String itemId) async {
    final doc = await _items.doc(itemId).get();
    final data = doc.data();
    return data == null ? null : GroceryItem.fromMap({...data, 'id': doc.id});
  }

  Future<List<GroceryItem>> getAllGroceryItems() async =>
      _fromSnapshot(await _items.orderBy('expiryDate').get());

  Future<List<GroceryItem>> getGroceryItemsByCategory(String category) async =>
      _fromSnapshot(
        await _items
            .where('category', isEqualTo: category)
            .orderBy('expiryDate')
            .get(),
      );

  Future<List<GroceryItem>> getExpiredGroceryItems() async {
    final today = GroceryItem.formatDateOnly(DateTime.now());
    return _fromSnapshot(
      await _items
          .where('expiryDate', isLessThan: today)
          .orderBy('expiryDate')
          .get(),
    );
  }

  Future<List<GroceryItem>> getGroceryItemsExpiringSoon({int days = 3}) async {
    final now = DateTime.now();
    final today = GroceryItem.formatDateOnly(now);
    final through = GroceryItem.formatDateOnly(now.add(Duration(days: days)));
    return _fromSnapshot(
      await _items
          .where('expiryDate', isGreaterThanOrEqualTo: today)
          .where('expiryDate', isLessThanOrEqualTo: through)
          .orderBy('expiryDate')
          .get(),
    );
  }

  Stream<List<GroceryItem>> streamGroceryItems() =>
      _items.orderBy('expiryDate').snapshots().map(_fromSnapshot);

  Stream<List<String>> streamCustomCategories() => _categories
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => doc.data()['name'])
            .whereType<String>()
            .toList(),
      );

  Future<void> saveCustomCategory({
    required String name,
    required String createdByUid,
  }) async {
    final normalized = _normalizeCategoryName(name);
    if (normalized == null) throw ArgumentError('Category name is required');
    final id = _categoryId(normalized);
    final now = DateTime.now().toUtc().toIso8601String();
    final ref = _categories.doc(id);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return;
      transaction.set(ref, {
        'name': normalized,
        'normalizedName': normalized.toLowerCase(),
        'createdByUid': createdByUid,
        'createdAt': now,
        'updatedAt': now,
      });
    });
  }

  Future<ProductLookupResult?> getCachedProduct(String barcode) async {
    final normalized = _normalizeBarcode(barcode);
    if (normalized == null) return null;
    final doc = await _productCache.doc(normalized).get();
    final data = doc.data();
    if (data == null) return null;
    return ProductLookupResult.fromHouseholdCache(normalized, data);
  }

  Future<void> saveCachedProduct({
    required String barcode,
    required String name,
    required String category,
    required String updatedByUid,
  }) async {
    final normalized = _normalizeBarcode(barcode);
    final normalizedName = _normalizeCategoryName(name);
    final normalizedCategory = _normalizeCategoryName(category);
    if (normalized == null || normalizedName == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _productCache.doc(normalized).set({
      'barcode': normalized,
      'name': normalizedName,
      if (normalizedCategory != null) 'category': normalizedCategory,
      'updatedByUid': updatedByUid,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<List<GroceryItem>> searchGroceryItems(String query) async {
    final allItems = _fromSnapshot(await _items.get());
    final normalized = query.trim().toLowerCase();
    return allItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(normalized) ||
              item.category.toLowerCase().contains(normalized) ||
              (item.barcode?.toLowerCase().contains(normalized) ?? false),
        )
        .toList();
  }

  Future<void> batchDeleteGroceryItems(List<String> itemIds) async {
    final batch = _firestore.batch();
    for (final id in itemIds) {
      batch.delete(_items.doc(id));
    }
    await batch.commit();
  }

  Future<Map<String, int>> getItemCountByCategory() async {
    final snapshot = await _items.get();
    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final category = doc.data()['category'] as String? ?? 'Other';
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  Future<int> cleanupExpiredItems({int daysAfterExpiry = 30}) async {
    final cutoff = GroceryItem.formatDateOnly(
      DateTime.now().subtract(Duration(days: daysAfterExpiry)),
    );
    final snapshot = await _items.where('expiryDate', isLessThan: cutoff).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  List<GroceryItem> _fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .map((doc) => GroceryItem.fromMap({...doc.data(), 'id': doc.id}))
      .toList();

  static String? _normalizeCategoryName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static String _categoryId(String name) {
    final normalized = name.toLowerCase();
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = safe.replaceAll(RegExp(r'^-+|-+$'), '');
    if (trimmed.isEmpty) {
      return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
    }
    return trimmed;
  }

  static String? _normalizeBarcode(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d{4,24}$').hasMatch(normalized)) return null;
    return normalized;
  }
}
