import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/grocery_item.dart';
import '../services/supabase_storage_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

/// ViewModel for managing grocery items.
class GroceryViewModel extends ChangeNotifier {
  List<GroceryItem> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _isUploading = false;

  final SupabaseStorageService _storageService =
      SupabaseStorageService.instance;
  final FirebaseFirestoreService _firestoreService =
      FirebaseFirestoreService.instance;
  final FirebaseAuthService _authService = FirebaseAuthService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  List<GroceryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUploading => _isUploading;

  List<GroceryItem> get expiredItems =>
      _items.where((item) => item.expiryStatus == ExpiryStatus.expired).toList();

  List<GroceryItem> get expiringSoonItems => _items
      .where((item) => item.expiryStatus == ExpiryStatus.expiringSoon)
      .toList();

  List<GroceryItem> get freshItems =>
      _items.where((item) => item.expiryStatus == ExpiryStatus.fresh).toList();

  Future<void> initialize() => loadItems();

  /// Load inventory from Firestore for the authenticated user.
  ///
  /// This intentionally does not create an anonymous session or substitute
  /// demo items when persistence fails. A persistence failure must be visible
  /// to the user during stabilization so the app never presents fake success.
  Future<void> loadItems() async {
    _setLoading(true);
    _clearError();

    try {
      if (!_authService.isSignedIn) {
        throw Exception('Sign in is required to load inventory');
      }

      _items = await _firestoreService.getAllGroceryItems();
      _sortItemsByExpiryDate();
      notifyListeners();
    } catch (e) {
      _items = [];
      _setError('Failed to load inventory: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Clear user-specific state on sign-out or account change.
  void reset() {
    _items = [];
    _error = null;
    _isLoading = false;
    _isUploading = false;
    notifyListeners();
  }

  Future<void> addItemWithImage(GroceryItem item, File? imageFile) async {
    _setUploading(true);
    _clearError();

    try {
      GroceryItem finalItem = item;

      if (imageFile != null) {
        final userId = _authService.currentUserId;
        if (userId == null) {
          throw Exception('Sign in is required to upload an item image');
        }

        final extension = getFileExtension(imageFile.path);
        final remotePath = getImageRemotePath(userId, item.id, extension);
        final imageUrl =
            await _storageService.uploadImage(imageFile, remotePath);
        finalItem = item.copyWith(imageUrl: imageUrl);
      }

      await addItem(finalItem);
      await _notificationService.scheduleExpiryNotification(finalItem);
    } catch (e) {
      _setError('Failed to add item: $e');
      rethrow;
    } finally {
      _setUploading(false);
    }
  }

  Future<void> addItem(GroceryItem item) async {
    _clearError();

    try {
      if (!_authService.isSignedIn) {
        throw Exception('Sign in is required to add inventory');
      }

      await _firestoreService.addGroceryItem(item);
      _items.removeWhere((existing) => existing.id == item.id);
      _items.add(item);
      _sortItemsByExpiryDate();
      notifyListeners();
    } catch (e) {
      _setError('Failed to save item: $e');
      rethrow;
    }
  }

  Future<void> updateItem(
    GroceryItem updatedItem, {
    File? newImageFile,
  }) async {
    _setUploading(newImageFile != null);
    _clearError();

    try {
      if (!_authService.isSignedIn) {
        throw Exception('Sign in is required to update inventory');
      }

      GroceryItem finalItem = updatedItem;

      if (newImageFile != null) {
        if (updatedItem.imageUrl != null) {
          await _deleteImageFromUrl(updatedItem.imageUrl!);
        }

        final userId = _authService.currentUserId!;
        final extension = getFileExtension(newImageFile.path);
        final remotePath =
            getImageRemotePath(userId, updatedItem.id, extension);
        final imageUrl =
            await _storageService.uploadImage(newImageFile, remotePath);
        finalItem = updatedItem.copyWith(imageUrl: imageUrl);
      }

      await _firestoreService.updateGroceryItem(finalItem);

      final index = _items.indexWhere((item) => item.id == finalItem.id);
      if (index != -1) {
        _items[index] = finalItem;
      } else {
        _items.add(finalItem);
      }
      _sortItemsByExpiryDate();
      notifyListeners();
    } catch (e) {
      _setError('Failed to update item: $e');
      rethrow;
    } finally {
      _setUploading(false);
    }
  }

  Future<void> deleteItem(String itemId) async {
    _clearError();

    try {
      if (!_authService.isSignedIn) {
        throw Exception('Sign in is required to delete inventory');
      }

      final item = _items.firstWhere((item) => item.id == itemId);

      if (item.imageUrl != null) {
        await _deleteImageFromUrl(item.imageUrl!);
      }

      await _firestoreService.deleteGroceryItem(itemId);
      await _notificationService.cancelExpiryNotifications(itemId);

      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete item: $e');
      rethrow;
    }
  }

  GroceryItem? getItemById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  List<GroceryItem> searchItems(String query) {
    if (query.isEmpty) return items;

    final normalized = query.toLowerCase();
    return _items.where((item) {
      return item.name.toLowerCase().contains(normalized) ||
          item.category.toLowerCase().contains(normalized) ||
          (item.barcode?.contains(normalized) ?? false);
    }).toList();
  }

  void clearError() => _clearError();

  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setUploading(bool uploading) {
    if (_isUploading == uploading) return;
    _isUploading = uploading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _sortItemsByExpiryDate() {
    _items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

  Future<void> _deleteImageFromUrl(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(supabaseStorageBucket);
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final imagePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _storageService.deleteImage(imagePath);
      }
    } catch (e) {
      debugPrint('Failed to delete image: $e');
    }
  }
}
