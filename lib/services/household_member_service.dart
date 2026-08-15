import 'package:cloud_functions/cloud_functions.dart';

import '../models/household.dart';

class HouseholdMemberService {
  HouseholdMemberService._();

  static final HouseholdMemberService instance = HouseholdMemberService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<HouseholdMember>> listMembers(String householdId) async {
    final result = await _functions.httpsCallable('listHouseholdMembers').call({
      'householdId': householdId,
    });
    final root = result.data is Map ? result.data as Map : const <Object?, Object?>{};
    final rawMembers = root['members'];
    if (rawMembers is! List) return const [];

    return rawMembers.whereType<Map>().map((raw) {
      final data = <String, dynamic>{};
      for (final entry in raw.entries) {
        if (entry.key is String) data[entry.key as String] = entry.value;
      }
      final uid = data['uid'] as String? ?? '';
      return HouseholdMember.fromMap(uid, data);
    }).where((member) => member.uid.isNotEmpty).toList();
  }

  Future<void> setRole({
    required String householdId,
    required String uid,
    required HouseholdRole role,
  }) async {
    if (role == HouseholdRole.owner) {
      throw ArgumentError('Ownership transfer is not supported here.');
    }
    await _functions.httpsCallable('setHouseholdMemberRole').call({
      'householdId': householdId,
      'uid': uid,
      'role': role.name,
    });
  }

  Future<void> removeMember({
    required String householdId,
    required String uid,
  }) async {
    await _functions.httpsCallable('removeHouseholdMember').call({
      'householdId': householdId,
      'uid': uid,
    });
  }
}
