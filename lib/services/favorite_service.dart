import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/favorite_item.dart';
import '../models/grocery_item.dart';
import 'firebase_auth_service.dart';

class FavoriteService {
  FavoriteService._();

  static final FavoriteService instance = FavoriteService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  CollectionReference<Map<String, dynamic>> get _favorites {
    final uid = _auth.currentUserId;
    if (uid == null) throw StateError('Sign in is required to use favorites');
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  Stream<List<FavoriteItem>> watchFavorites() {
    return _favorites.orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => FavoriteItem.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<bool> watchIsFavorite(GroceryItem item) {
    final id = FavoriteItem.idForItem(item);
    return _favorites.doc(id).snapshots().map((snapshot) => snapshot.exists);
  }

  Future<void> saveFromItem(GroceryItem item) async {
    final favorite = FavoriteItem.fromGroceryItem(item);
    final ref = _favorites.doc(favorite.id);
    final existing = await ref.get();
    final existingCreatedAt = existing.data()?['createdAt'];
    final data = favorite.toMap();
    if (existingCreatedAt is String) data['createdAt'] = existingCreatedAt;
    data['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await ref.set(data);
  }

  Future<void> removeForItem(GroceryItem item) {
    return _favorites.doc(FavoriteItem.idForItem(item)).delete();
  }

  Future<void> removeFavorite(FavoriteItem favorite) {
    return _favorites.doc(favorite.id).delete();
  }
}
