import 'package:cloud_functions/cloud_functions.dart';

class DiscordIntegrationStatus {
  const DiscordIntegrationStatus({
    required this.configured,
    required this.enabled,
  });

  final bool configured;
  final bool enabled;

  factory DiscordIntegrationStatus.fromData(Object? raw) {
    final data = raw is Map ? raw : const <Object?, Object?>{};
    return DiscordIntegrationStatus(
      configured: data['configured'] == true,
      enabled: data['enabled'] == true,
    );
  }
}

class DiscordReminderService {
  DiscordReminderService._();

  static final DiscordReminderService instance = DiscordReminderService._();

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<DiscordIntegrationStatus> getStatus(String householdId) async {
    final result = await _functions.httpsCallable('getDiscordIntegrationStatus').call({
      'householdId': householdId,
    });
    return DiscordIntegrationStatus.fromData(result.data);
  }

  Future<DiscordIntegrationStatus> save({
    required String householdId,
    required bool enabled,
    String? webhookUrl,
  }) async {
    final result = await _functions.httpsCallable('setDiscordIntegration').call({
      'householdId': householdId,
      'enabled': enabled,
      if (webhookUrl != null && webhookUrl.trim().isNotEmpty)
        'webhookUrl': webhookUrl.trim(),
    });
    return DiscordIntegrationStatus.fromData(result.data);
  }

  Future<void> sendTest(String householdId) async {
    await _functions.httpsCallable('testDiscordIntegration').call({
      'householdId': householdId,
    });
  }
}
