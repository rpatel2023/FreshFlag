import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_rule.dart';

class NotificationRuleService {
  NotificationRuleService._();
  static final NotificationRuleService instance = NotificationRuleService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _rules(String householdId) =>
      _firestore.collection('households').doc(householdId).collection('notificationRules');

  Stream<List<NotificationRule>> watchRules(String householdId) {
    return _rules(householdId).snapshots().map((snapshot) {
      final rules = snapshot.docs
          .map((doc) => NotificationRule.fromMap(doc.id, doc.data()))
          .toList();
      rules.sort((a, b) => b.daysBefore.compareTo(a.daysBefore));
      return rules;
    });
  }

  Future<NotificationRule> createRule({
    required String householdId,
    required int daysBefore,
    required String titleTemplate,
    required String bodyTemplate,
    required String sendTime,
  }) async {
    if (daysBefore < 0 || daysBefore > 365) {
      throw ArgumentError.value(daysBefore, 'daysBefore', 'Must be between 0 and 365');
    }
    final title = titleTemplate.trim();
    final body = bodyTemplate.trim();
    if (title.isEmpty || body.isEmpty) {
      throw ArgumentError('Notification title and body are required');
    }

    final now = DateTime.now().toUtc();
    final ref = _rules(householdId).doc();
    final rule = NotificationRule(
      id: ref.id,
      daysBefore: daysBefore,
      titleTemplate: title,
      bodyTemplate: body,
      sendTime: NotificationRule.normalizeSendTime(sendTime),
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(rule.toMap());
    return rule;
  }

  Future<void> updateRule(String householdId, NotificationRule rule) async {
    final normalized = rule.copyWith(updatedAt: DateTime.now().toUtc());
    await _rules(householdId).doc(rule.id).set(
          normalized.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteRule(String householdId, String ruleId) =>
      _rules(householdId).doc(ruleId).delete();
}
