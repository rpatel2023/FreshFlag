import 'package:cloud_functions/cloud_functions.dart';

class DiscordIntegrationStatus {
  const DiscordIntegrationStatus({
    required this.configured,
    required this.enabled,
    required this.itemAddedEnabled,
    required this.itemChangedEnabled,
    required this.itemRemovedEnabled,
    required this.itemConsumedEnabled,
    required this.itemRestoredEnabled,
  });

  final bool configured;
  final bool enabled;
  final bool itemAddedEnabled;
  final bool itemChangedEnabled;
  final bool itemRemovedEnabled;
  final bool itemConsumedEnabled;
  final bool itemRestoredEnabled;

  factory DiscordIntegrationStatus.fromData(Object? raw) {
    final data = raw is Map ? raw : const <Object?, Object?>{};
    return DiscordIntegrationStatus(
      configured: data['configured'] == true,
      enabled: data['enabled'] == true,
      itemAddedEnabled: data['itemAddedEnabled'] == true,
      itemChangedEnabled: data['itemChangedEnabled'] == true,
      itemRemovedEnabled: data['itemRemovedEnabled'] == true,
      itemConsumedEnabled: data['itemConsumedEnabled'] == true,
      itemRestoredEnabled: data['itemRestoredEnabled'] == true,
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
    bool? itemChangedEnabled,
    bool? itemRemovedEnabled,
    bool? itemConsumedEnabled,
    bool? itemRestoredEnabled,
    String? webhookUrl,
  }) async {
    final result = await _functions
        .httpsCallable('setDiscordIntegration')
        .call({
          if (enabled != null) 'enabled': enabled,
          if (itemAddedEnabled != null) 'itemAddedEnabled': itemAddedEnabled,
          if (itemChangedEnabled != null)
            'itemChangedEnabled': itemChangedEnabled,
          if (itemRemovedEnabled != null)
            'itemRemovedEnabled': itemRemovedEnabled,
          if (itemConsumedEnabled != null)
            'itemConsumedEnabled': itemConsumedEnabled,
          if (itemRestoredEnabled != null)
            'itemRestoredEnabled': itemRestoredEnabled,
          if (webhookUrl != null && webhookUrl.trim().isNotEmpty)
            'webhookUrl': webhookUrl.trim(),
        });
    return DiscordIntegrationStatus.fromData(result.data);
  }

  Future<void> sendTest() async {
    await _functions.httpsCallable('testDiscordIntegration').call();
  }
}
