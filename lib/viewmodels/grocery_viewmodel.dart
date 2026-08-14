import 'package:flutter/foundation.dart';

import '../models/grocery_item.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/notification_service.dart';

/// Authoritative inventory state for the currently selected household.
class GroceryViewModel extends ChangeNotifier {
  List<GroceryItem> _items = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  String? _householdId;

  final FirebaseFirestoreService _firestore = FirebaseFirestoreService.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<GroceryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  String? get householdId => _householdId;

  List<GroceryItem> get expiredItems => _items
      .where((item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.expired)
      .toList();

  List<GroceryItem> get expiringSoonItems => _items
      .where((item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.expiringSoon)
      .toList();

  List<GroceryItem> get freshItems => _items
      .where((item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.fresh)
      .toList();

  Future<void> bindHousehold(String householdId) async {
    if (_householdId == householdId) return;
    _householdId = householdId;
    _firestore.setHousehold(householdId);
    await loadItems();
  }

  Future<void> loadItems() async {
    if (!_auth.isSignedIn || _householdId == null) {
      reset();
      return;
    }

    _setLoading(true);
    _clearError();
    try {
      _items = await _firestore.getAllGroceryItems();
      _sortItems();
      notifyListeners();
    } catch (e) {
      _items = [];
      _setError('Failed to load inventory: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addItem(GroceryItem item) async {
    final householdId = _requireContext('add inventory');
    final uid = _auth.currentUserId!;
    final now = DateTime.now().toUtc();
    final persisted = item.copyWith(
      householdId: householdId,
      createdByUid: item.createdByUid ?? uid,
      updatedByUid: uid,
      updatedAt: now,
    );

    _setUploading(true);
    _clearError();
    try {
      await _firestore.addGroceryItem(persisted);
      _items.removeWhere((existing) => existing.id == persisted.id);
      _items.add(persisted);
      _sortItems();
      notifyListeners();
      await _notifications.scheduleExpiryNotification(persisted);
    } catch (e) {
      _setError('Failed to save item: $e');
      rethrow;
    } finally {
      _setUploading(false);
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
      final index = _items.indexWhere((existing) => existing.id == persisted.id);
      if (index == -1) {
        _items.add(persisted);
      } else {
        _items[index] = persisted;
      }
      _sortItems();
      notifyListeners();
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
      await _notifications.cancelExpiryNotifications(itemId);
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
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

  List<GroceryItem> searchItems(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return items;
    return _items.where((item) =>
        item.name.toLowerCase().contains(normalized) ||
        item.category.toLowerCase().contains(normalized) ||
        (item.barcode?.toLowerCase().contains(normalized) ?? false)).toList();
  }

  void clearError() => _clearError();

  void reset() {
    _householdId = null;
    _firestore.setHousehold(null);
    _items = [];
    _isLoading = false;
    _isUploading = false;
    _error = null;
    notifyListeners();
  }

  String _requireContext(String operation) {
    if (!_auth.isSignedIn) throw StateError('Sign in is required to $operation');
    final householdId = _householdId;
    if (householdId == null) throw StateError('Select a household to $operation');
    return householdId;
  }

  void _sortItems() => _items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
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
}
