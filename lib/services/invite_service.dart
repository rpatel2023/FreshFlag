import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/household.dart';
import '../models/household_invite.dart';
import 'firebase_auth_service.dart';

class InviteService {
  InviteService._();
  static final InviteService instance = InviteService._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;
  final Random _random = Random.secure();

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

  Future<HouseholdInvite> createInvite(
    String householdId, {
    Duration lifetime = const Duration(days: 7),
  }) async {
    final uid = _uid;
    final code = _generateCode();
    final createdAt = DateTime.now().toUtc();
    final expiresAt = createdAt.add(lifetime);
    final invite = HouseholdInvite(
      code: code,
      householdId: householdId,
      createdByUid: uid,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: HouseholdInviteStatus.active,
    );

    await _firestore.collection('invites').doc(code).set({
      'householdId': householdId,
      'createdByUid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': HouseholdInviteStatus.active.name,
    });
    return invite;
  }

  Future<void> revokeInvite(HouseholdInvite invite) async {
    await _firestore.collection('invites').doc(invite.code).update({
      'status': HouseholdInviteStatus.revoked.name,
      'revokedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'revokedByUid': _uid,
    });
  }

  Future<Household> joinHousehold(String rawCode) async {
    final uid = _uid;
    final code = HouseholdInvite.normalizeCode(rawCode);
    if (code.length != 12) {
      throw const FormatException('Invite code must be 12 characters');
    }

    // The invite itself is the only document an outsider is allowed to read.
    // The household remains private until membership is atomically created.
    final inviteRef = _firestore.collection('invites').doc(code);
    final inviteSnapshot = await inviteRef.get();
    final inviteData = inviteSnapshot.data();
    if (inviteData == null) throw StateError('Invite not found');

    final status = inviteData['status'] as String?;
    final expiresAt = (inviteData['expiresAt'] as Timestamp?)?.toDate().toUtc();
    final householdId = inviteData['householdId'] as String?;
    if (status != HouseholdInviteStatus.active.name ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now().toUtc()) ||
        householdId == null ||
        householdId.isEmpty) {
      throw StateError('Invite is invalid or expired');
    }

    final householdRef = _firestore.collection('households').doc(householdId);
    final memberRef = householdRef.collection('members').doc(uid);
    final userRef = _firestore.collection('users').doc(uid);
    final joinedAt = DateTime.now().toUtc();

    // No household read happens before this batch. Security Rules validate the
    // existing household plus the invite server-side while the client only
    // supplies the intended self-membership mutation.
    final batch = _firestore.batch();
    batch.update(householdRef, {
      'memberUids': FieldValue.arrayUnion([uid]),
      'lastJoinInviteId': code,
      'updatedAt': joinedAt.toIso8601String(),
    });
    batch.set(memberRef, {
      'uid': uid,
      'role': HouseholdRole.member.name,
      'joinedAt': joinedAt.toIso8601String(),
      'inviteId': code,
      if (_displayName?.isNotEmpty == true) 'displayName': _displayName,
    });
    batch.set(
      userRef,
      {
        'currentHouseholdId': householdId,
        'updatedAt': joinedAt.toIso8601String(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    // Membership now exists, so the normal household read rule applies.
    final householdSnapshot = await householdRef.get();
    final householdData = householdSnapshot.data();
    if (householdData == null) {
      throw StateError('Household no longer exists');
    }
    return Household.fromMap(householdSnapshot.id, householdData);
  }

  String _generateCode() {
    return List.generate(
      12,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }
}
