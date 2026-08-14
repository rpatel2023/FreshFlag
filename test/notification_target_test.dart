import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/models/notification_target.dart';

void main() {
  group('NotificationTarget', () {
    test('parses the expiry payload used for deep linking', () {
      final target = NotificationTarget.fromData({
        'type': 'expiry',
        'householdId': 'house-1',
        'itemId': 'item-7',
        'ruleId': 'rule-3',
      });

      expect(target, isNotNull);
      expect(target!.householdId, 'house-1');
      expect(target.itemId, 'item-7');
      expect(target.key, 'house-1:item-7');
    });

    test('accepts Phase 6 legacy expiry_reminder payloads', () {
      final target = NotificationTarget.fromData({
        'type': 'expiry_reminder',
        'householdId': 'house-1',
        'itemId': 'item-7',
      });

      expect(target, isNotNull);
    });

    test('rejects unrelated or incomplete payloads', () {
      expect(
        NotificationTarget.fromData({
          'type': 'chat',
          'householdId': 'house-1',
          'itemId': 'item-7',
        }),
        isNull,
      );
      expect(
        NotificationTarget.fromData({
          'type': 'expiry',
          'householdId': 'house-1',
        }),
        isNull,
      );
      expect(
        NotificationTarget.fromData({
          'type': 'expiry',
          'householdId': ' ',
          'itemId': 'item-7',
        }),
        isNull,
      );
    });
  });
}
