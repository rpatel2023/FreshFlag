import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/household.dart';
import '../models/notification_rule.dart';
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

  String? get _displayName {
    final user = _auth.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email?.trim();
    if (email == null || email.isEmpty) return null;
    return email.split('@').first;
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
    _validateHouseholdSettings(trimmedName, trimmedTimezone);

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
        displayName: _displayName,
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

    for (final rule in _defaultNotificationRules(now)) {
      batch.set(
        ref.collection('notificationRules').doc(rule.id),
        rule.toMap(),
      );
    }

    await batch.commit();
    return household;
  }

  Future<Household> updateHousehold(
    String householdId, {
    required String name,
    required String timezone,
  }) async {
    final trimmedName = name.trim();
    final trimmedTimezone = timezone.trim();
    _validateHouseholdSettings(trimmedName, trimmedTimezone);

    final ref = _households.doc(householdId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) throw StateError('Household not found');
    if (data['ownerUid'] != _uid) {
      throw StateError('Only the household owner can change household settings');
    }

    final updatedAt = DateTime.now().toUtc();
    await ref.update({
      'name': trimmedName,
      'timezone': trimmedTimezone,
      'updatedAt': updatedAt.toIso8601String(),
    });

    return Household.fromMap(
      householdId,
      {
        ...data,
        'name': trimmedName,
        'timezone': trimmedTimezone,
        'updatedAt': updatedAt.toIso8601String(),
      },
    );
  }

  Stream<List<HouseholdMember>> watchMembers(String householdId) {
    return _households
        .doc(householdId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      final members = snapshot.docs
          .map((doc) => HouseholdMember.fromMap(doc.id, doc.data()))
          .toList();
      members.sort((a, b) {
        if (a.role != b.role) {
          return a.role == HouseholdRole.owner ? -1 : 1;
        }
        return a.joinedAt.compareTo(b.joinedAt);
      });
      return members;
    });
  }

  Future<void> removeMember(String householdId, String memberUid) async {
    final householdRef = _households.doc(householdId);
    final snapshot = await householdRef.get();
    final data = snapshot.data();
    if (data == null) throw StateError('Household not found');
    if (data['ownerUid'] != _uid) {
      throw StateError('Only the household owner can remove members');
    }
    if (memberUid == _uid) {
      throw StateError('The owner cannot remove themselves');
    }

    final memberUids = List<String>.from(
      data['memberUids'] as List? ?? const [],
    );
    if (!memberUids.contains(memberUid)) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _firestore.batch();
    batch.update(householdRef, {
      'memberUids': FieldValue.arrayRemove([memberUid]),
      'lastRemovedUid': memberUid,
      'updatedAt': now,
    });
    batch.delete(householdRef.collection('members').doc(memberUid));
    await batch.commit();
  }

  Future<void> leaveHousehold(String householdId) async {
    final uid = _uid;
    final householdRef = _households.doc(householdId);
    final snapshot = await householdRef.get();
    final data = snapshot.data();
    if (data == null) throw StateError('Household not found');
    if (data['ownerUid'] == uid) {
      throw StateError(
        'The household owner cannot leave until ownership transfer is available',
      );
    }

    final memberUids = List<String>.from(
      data['memberUids'] as List? ?? const [],
    );
    if (!memberUids.contains(uid)) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _firestore.batch();
    batch.update(householdRef, {
      'memberUids': FieldValue.arrayRemove([uid]),
      'updatedAt': now,
    });
    batch.delete(householdRef.collection('members').doc(uid));
    batch.set(
      _firestore.collection('users').doc(uid),
      {
        'currentHouseholdId': FieldValue.delete(),
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> setPreferredHousehold(String householdId) async {
    final household = await _households.doc(householdId).get();
    final data = household.data();
    final members = List<String>.from(
      data?['memberUids'] as List? ?? const [],
    );
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

  void _validateHouseholdSettings(String name, String timezone) {
    if (name.isEmpty) throw ArgumentError('Household name is required');
    if (timezone.isEmpty || !timezone.contains('/')) {
      throw ArgumentError('Use an IANA timezone such as America/Toronto');
    }
  }

  List<NotificationRule> _defaultNotificationRules(DateTime now) => [
        NotificationRule(
          id: 'default-3-days',
          daysBefore: 3,
          titleTemplate: '{item} expires soon',
          bodyTemplate: '{item} expires in {days} days',
          sendTime: '09:00',
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
        NotificationRule(
          id: 'default-1-day',
          daysBefore: 1,
          titleTemplate: '{item} expires tomorrow',
          bodyTemplate: '{item} expires tomorrow',
          sendTime: '09:00',
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
        NotificationRule(
          id: 'default-expiry-day',
          daysBefore: 0,
          titleTemplate: '{item} expires today',
          bodyTemplate: '{item} expires today',
          sendTime: '09:00',
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];
}
