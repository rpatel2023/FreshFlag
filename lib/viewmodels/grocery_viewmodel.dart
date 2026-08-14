import 'package:flutter/foundation.dart';

import '../models/grocery_item.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/notification_service.dart';

/// Authoritative single-user inventory state for Phase 1.
///
/// Firestore is the source of truth. Local/demo fallbacks and Supabase-backed
/// image storage are intentionally excluded from this layer.
class GroceryViewModel extends ChangeNotifier {
  List<GroceryItem> _items = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;

  final FirebaseFirestoreService _firestore =
      FirebaseFirestoreService.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<GroceryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;

  List<GroceryItem> get expiredItems => _items
      .where((item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.expired)
      .toList();

  List<GroceryItem> get expiringSoonItems => _items
      .where(
        (item) =>
            !item.isConsumed &&
            item.expiryStatus == ExpiryStatus.expiringSoon,
      )
      .toList();

  List<GroceryItem> get freshItems => _items
      .where((item) => !item.isConsumed && item.expiryStatus == ExpiryStatus.fresh)
      .toList();

  Future<void> initialize() => loadItems();

  Future<void> loadItems() async {
    if (!_auth.isSignedIn) {
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
    _requireSignedIn('add inventory');
    _setUploading(true);
    _clearError();
    try {
      await _firestore.addGroceryItem(item);
      _items.removeWhere((existing) => existing.id == item.id);
      _items.add(item);
      _sortItems();
      notifyListeners();

      // Local reminders remain a temporary Phase 1 capability. Household
      // backend scheduling replaces this in the notification phases.
      await _notifications.scheduleExpiryNotification(item);
    } catch (e) {
      _setError('Failed to save item: $e');
      rethrow;
    } finally {
      _setUploading(false);
    }
  }

  Future<void> updateItem(GroceryItem item) async {
    _requireSignedIn('update inventory');
    _setUploading(true);
    _clearError();
    try {
      await _firestore.updateGroceryItem(item);
      final index = _items.indexWhere((existing) => existing.id == item.id);
      if (index == -1) {
        _items.add(item);
      } else {
        _items[index] = item;
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
    _requireSignedIn('delete inventory');
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

    return _items.where((item) {
      return item.name.toLowerCase().contains(normalized) ||
          item.category.toLowerCase().contains(normalized) ||
          (item.barcode?.toLowerCase().contains(normalized) ?? false);
    }).toList();
  }

  void clearError() => _clearError();

  void reset() {
    _items = [];
    _isLoading = false;
    _isUploading = false;
    _error = null;
    notifyListeners();
  }

  void _requireSignedIn(String operation) {
    if (!_auth.isSignedIn) {
      throw StateError('Sign in is required to $operation');
    }
  }

  void _sortItems() {
    _items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

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
