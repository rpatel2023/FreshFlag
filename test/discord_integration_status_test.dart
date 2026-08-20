import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/services/discord_reminder_service.dart';

void main() {
  test('Discord integration status parses configured and enabled flags', () {
    final status = DiscordIntegrationStatus.fromData({
      'configured': true,
      'enabled': true,
      'itemAddedEnabled': true,
      'itemChangedEnabled': true,
      'itemRemovedEnabled': true,
      'itemConsumedEnabled': true,
      'itemRestoredEnabled': true,
    });

    expect(status.configured, isTrue);
    expect(status.enabled, isTrue);
    expect(status.itemAddedEnabled, isTrue);
    expect(status.itemChangedEnabled, isTrue);
    expect(status.itemRemovedEnabled, isTrue);
    expect(status.itemConsumedEnabled, isTrue);
    expect(status.itemRestoredEnabled, isTrue);
  });

  test(
    'Discord integration status defaults safely for malformed responses',
    () {
      for (final value in <Object?>[
        null,
        'invalid',
        <String, Object?>{},
        <String, Object?>{'configured': 'true', 'enabled': 1},
      ]) {
        final status = DiscordIntegrationStatus.fromData(value);
        expect(status.configured, isFalse);
        expect(status.enabled, isFalse);
        expect(status.itemAddedEnabled, isFalse);
        expect(status.itemChangedEnabled, isFalse);
        expect(status.itemRemovedEnabled, isFalse);
        expect(status.itemConsumedEnabled, isFalse);
        expect(status.itemRestoredEnabled, isFalse);
      }
    },
  );
}
