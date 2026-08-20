import 'package:cloud_functions/cloud_functions.dart';

class DiscordIntegrationStatus {
  const DiscordIntegrationStatus({
    required this.configured,
    required this.enabled,
    required this.itemAddedEnabled,
  });

  final bool configured;
  final bool enabled;
  final bool itemAddedEnabled;

  factory DiscordIntegrationStatus.fromData(Object? raw) {
    final data = raw is Map ? raw : const <Object?, Object?>{};
    return DiscordIntegrationStatus(
      configured: data['configured'] == true,
      enabled: data['enabled'] == true,
      itemAddedEnabled: data['itemAddedEnabled'] == true,
    );
  }
}

class DiscordReminderService {
  DiscordReminderService._();

  static final DiscordReminderService instance = DiscordReminderService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<DiscordIntegrationStatus> getStatus() async {
    final result = await _functions
        .httpsCallable('getDiscordIntegrationStatus')
        .call();
    return DiscordIntegrationStatus.fromData(result.data);
  }

  Future<DiscordIntegrationStatus> save({
    bool? enabled,
    bool? itemAddedEnabled,
    String? webhookUrl,
  }) async {
    final result = await _functions
        .httpsCallable('setDiscordIntegration')
        .call({
          if (enabled != null) 'enabled': enabled,
          if (itemAddedEnabled != null) 'itemAddedEnabled': itemAddedEnabled,
          if (webhookUrl != null && webhookUrl.trim().isNotEmpty)
            'webhookUrl': webhookUrl.trim(),
        });
    return DiscordIntegrationStatus.fromData(result.data);
  }

  Future<void> sendTest() async {
    await _functions.httpsCallable('testDiscordIntegration').call();
  }
}
