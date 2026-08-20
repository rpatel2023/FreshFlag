import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_activity.dart';

class ActivityService {
  ActivityService._();

  static final ActivityService instance = ActivityService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<InventoryActivity>> streamRecentActivity(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(InventoryActivity.fromSnapshot).toList(),
        );
  }
}
