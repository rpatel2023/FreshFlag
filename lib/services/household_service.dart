import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/household.dart';
import 'firebase_auth_service.dart';

class HouseholdService {
  HouseholdService._();
  static final HouseholdService instance = HouseholdService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  String get _uid {
    final uid = _auth.currentUserId;
    if (uid == null) throw StateError('User not authenticated');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _households =>
      _firestore.collection('households');

  Future<List<Household>> listMyHouseholds() async {
    final snapshot = await _households
        .where('memberUids', arrayContains: _uid)
        .get();
    final households = snapshot.docs
        .map((doc) => Household.fromMap(doc.id, doc.data()))
        .toList();
    households.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return households;
  }

  Future<String?> getPreferredHouseholdId() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    return doc.data()?['currentHouseholdId'] as String?;
  }

  Future<Household> createHousehold({
    required String name,
    required String timezone,
  }) async {
    final trimmedName = name.trim();
    final trimmedTimezone = timezone.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Household name is required');
    if (trimmedTimezone.isEmpty) throw ArgumentError('Timezone is required');

    final uid = _uid;
    final now = DateTime.now().toUtc();
    final ref = _households.doc();
    final household = Household(
      id: ref.id,
      name: trimmedName,
      ownerUid: uid,
      memberUids: [uid],
      timezone: trimmedTimezone,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(ref, household.toMap());
    batch.set(
      ref.collection('members').doc(uid),
      HouseholdMember(
        uid: uid,
        role: HouseholdRole.owner,
        joinedAt: now,
        displayName: _auth.currentUser?.displayName,
      ).toMap(),
    );
    batch.set(
      _firestore.collection('users').doc(uid),
      {
        'currentHouseholdId': ref.id,
        'updatedAt': now.toIso8601String(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return household;
  }

  Future<void> setPreferredHousehold(String householdId) async {
    final household = await _households.doc(householdId).get();
    final data = household.data();
    final members = List<String>.from(data?['memberUids'] as List? ?? const []);
    if (data == null || !members.contains(_uid)) {
      throw StateError('Current user is not a member of this household');
    }
    await _firestore.collection('users').doc(_uid).set(
      {
        'currentHouseholdId': householdId,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<HouseholdMember?> getMembership(String householdId) async {
    final doc = await _households
        .doc(householdId)
        .collection('members')
        .doc(_uid)
        .get();
    final data = doc.data();
    return data == null ? null : HouseholdMember.fromMap(doc.id, data);
  }

  Stream<HouseholdMember?> watchMembership(String householdId) {
    return _households
        .doc(householdId)
        .collection('members')
        .doc(_uid)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      return data == null ? null : HouseholdMember.fromMap(doc.id, data);
    });
  }
}
