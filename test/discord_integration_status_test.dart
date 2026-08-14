import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/services/discord_reminder_service.dart';

void main() {
  test('Discord integration status parses configured and enabled flags', () {
    final status = DiscordIntegrationStatus.fromData({
      'configured': true,
      'enabled': true,
    });

    expect(status.configured, isTrue);
    expect(status.enabled, isTrue);
  });

  test('Discord integration status defaults safely for malformed responses', () {
    for (final value in <Object?>[
      null,
      'invalid',
      <String, Object?>{},
      <String, Object?>{'configured': 'true', 'enabled': 1},
    ]) {
      final status = DiscordIntegrationStatus.fromData(value);
      expect(status.configured, isFalse);
      expect(status.enabled, isFalse);
    }
  });
}
