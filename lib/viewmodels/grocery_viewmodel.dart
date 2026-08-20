import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/grocery_item.dart';
import '../models/inventory_category.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_firestore_service.dart';

/// Authoritative real-time inventory state for the selected household.
///
/// Expiry reminder delivery is backend-driven. This ViewModel never schedules
/// device-local expiry notifications, which avoids duplicate or rule-divergent
/// reminders across household members.
class GroceryViewModel extends ChangeNotifier {
  List<GroceryItem> _items = [];
  List<String> _customCategories = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  String? _householdId;
  StreamSubscription<List<GroceryItem>>? _inventorySubscription;
  StreamSubscription<List<String>>? _categorySubscription;

  final FirebaseFirestoreService _firestore = FirebaseFirestoreService.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  List<GroceryItem> get items => List.unmodifiable(_items);
  List<String> get customCategories => List.unmodifiable(_customCategories);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  String? get householdId => _householdId;

  List<GroceryItem> get expiredItems => _items
      .where(
        (item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.expired,
      )
      .toList();

  List<GroceryItem> get expiringSoonItems => _items
      .where(
        (item) =>
            !item.isConsumed && item.expiryStatus == ExpiryStatus.expiringSoon,
      )
      .toList();

  List<GroceryItem> get freshItems => _items
      .where(
        (item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.fresh,
      )
      .toList();

  Future<void> bindHousehold(String householdId) async {
    if (_householdId == householdId && _inventorySubscription != null) return;
    await _inventorySubscription?.cancel();
    await _categorySubscription?.cancel();
    _householdId = householdId;
    _firestore.setHousehold(householdId);
    _items = [];
    _customCategories = [];
    _error = null;
    _setLoading(true);

    _inventorySubscription = _firestore.streamGroceryItems().listen(
      (items) {
        _items = items;
        _sortItems();
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _items = [];
        _isLoading = false;
        _error = 'Failed to stream inventory: $error';
        notifyListeners();
      },
    );

    _categorySubscription = _firestore.streamCustomCategories().listen(
      (categories) {
        _customCategories = categories;
        notifyListeners();
      },
      onError: (Object error) {
        _error = 'Failed to stream categories: $error';
        notifyListeners();
      },
    );
  }

  Future<void> loadItems() async {
    final householdId = _householdId;
    if (!_auth.isSignedIn || householdId == null) {
      await reset();
      return;
    }
    await bindHousehold(householdId);
  }

  Future<void> addItem(GroceryItem item) async {
    final householdId = _requireContext('add inventory');
    final uid = _auth.currentUserId!;
    final persisted = item.copyWith(
      householdId: householdId,
      createdByUid: item.createdByUid ?? uid,
      updatedByUid: uid,
      updatedAt: DateTime.now().toUtc(),
    );

    _setUploading(true);
    _clearError();
    try {
      await _firestore.addGroceryItem(persisted);
    } catch (e) {
      _setError('Failed to save item: $e');
      rethrow;
    } finally {
      _setUploading(false);
    }
  }

  Future<void> createCustomCategory(String name) async {
    _requireContext('create category');
    final normalized = InventoryCategories.clean(name);
    if (normalized == null) throw ArgumentError('Category name is required');
    final knownCategories = InventoryCategories.forItems(
      _items,
      savedCategories: _customCategories,
    );
    if (knownCategories.contains(normalized)) return;
    final uid = _auth.currentUserId!;
    _clearError();
    try {
      await _firestore.saveCustomCategory(name: normalized, createdByUid: uid);
    } catch (e) {
      _setError('Failed to save category: $e');
      rethrow;
    }
  }

  Future<void> updateItem(GroceryItem item) async {
    final householdId = _requireContext('update inventory');
    final uid = _auth.currentUserId!;
    final persisted = item.copyWith(
      householdId: householdId,
      updatedByUid: uid,
      updatedAt: DateTime.now().toUtc(),
    );

    _setUploading(true);
    _clearError();
    try {
      await _firestore.updateGroceryItem(persisted);
    } catch (e) {
      _setError('Failed to update item: $e');
      rethrow;
    } finally {
      _setUploading(false);
    }
  }

  Future<void> deleteItem(String itemId) async {
    _requireContext('delete inventory');
    _clearError();
    try {
      await _firestore.deleteGroceryItem(itemId);
    } catch (e) {
      _setError('Failed to delete item: $e');
      rethrow;
    }
  }

  GroceryItem? getItemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<GroceryItem?> fetchItem(String itemId) async {
    _requireContext('open inventory');
    try {
      return await _firestore.getGroceryItem(itemId);
    } catch (e) {
      _setError('Failed to load item: $e');
      rethrow;
    }
  }

  List<GroceryItem> searchItems(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return items;
    return _items
        .where(
          (item) =>
              item.name.toLowerCase().contains(normalized) ||
              item.category.toLowerCase().contains(normalized) ||
              (item.barcode?.toLowerCase().contains(normalized) ?? false),
        )
        .toList();
  }

  void clearError() => _clearError();

  Future<void> reset() async {
    await _inventorySubscription?.cancel();
    await _categorySubscription?.cancel();
    _inventorySubscription = null;
    _categorySubscription = null;
    _householdId = null;
    _firestore.setHousehold(null);
    _items = [];
    _customCategories = [];
    _isLoading = false;
    _isUploading = false;
    _error = null;
    notifyListeners();
  }

  String _requireContext(String operation) {
    if (!_auth.isSignedIn) {
      throw StateError('Sign in is required to $operation');
    }
    final householdId = _householdId;
    if (householdId == null) {
      throw StateError('Select a household to $operation');
    }
    return householdId;
  }

  void _sortItems() =>
      _items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setUploading(bool value) {
    if (_isUploading == value) return;
    _isUploading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _categorySubscription?.cancel();
    super.dispose();
  }
}
