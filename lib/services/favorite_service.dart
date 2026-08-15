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
    if (uid == null) throw StateError('Sign in is required to use favourites');
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
    return watchFavorites().map(
      (favorites) => favorites.any((favorite) => favorite.matches(item)),
    );
  }

  Future<void> saveFromItem(GroceryItem item) async {
    final candidate = FavoriteItem.fromGroceryItem(item);
    final snapshot = await _favorites.get();
    QueryDocumentSnapshot<Map<String, dynamic>>? matchedDocument;

    for (final document in snapshot.docs) {
      final existing = FavoriteItem.fromMap(document.id, document.data());
      if (existing.matches(item)) {
        matchedDocument = document;
        break;
      }
    }

    final ref = matchedDocument?.reference ?? _favorites.doc(candidate.id);
    final data = candidate.toMap();
    data['id'] = ref.id;
    final existingCreatedAt = matchedDocument?.data()['createdAt'];
    if (existingCreatedAt is String) data['createdAt'] = existingCreatedAt;
    data['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await ref.set(data);
  }

  Future<void> removeForItem(GroceryItem item) async {
    final snapshot = await _favorites.get();
    final matches = snapshot.docs.where((document) {
      return FavoriteItem.fromMap(document.id, document.data()).matches(item);
    }).toList();

    await Future.wait(matches.map((document) => document.reference.delete()));
  }

  Future<void> removeFavorite(FavoriteItem favorite) {
    return _favorites.doc(favorite.id).delete();
  }
}
