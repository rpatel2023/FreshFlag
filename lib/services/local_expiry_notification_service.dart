import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/distribution_config.dart';
import '../models/grocery_item.dart';
import 'local_database_service.dart';

class LocalExpiryNotificationService {
  LocalExpiryNotificationService._();

  static final LocalExpiryNotificationService instance =
      LocalExpiryNotificationService._();

  static const _channelId = 'freshflag_local_expiry';
  static const _channelName = 'Expiry reminders';
  static const _channelDescription =
      'On-device expiry reminders for SideStore builds.';
  static const _maxScheduledItems = 50;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (!DistributionConfig.isSideStore || _initialized) return;

    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!DistributionConfig.isSideStore) return false;
    await initialize();

    final iosGranted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    final macGranted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    final androidGranted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;

    return iosGranted && macGranted && androidGranted;
  }

  Future<void> setEnabled(bool enabled, Iterable<GroceryItem> items) async {
    await LocalDatabaseService.setLocalExpiryRemindersEnabled(enabled);
    if (!enabled) {
      await cancelAll();
      return;
    }

    final granted = await requestPermission();
    if (!granted) {
      await LocalDatabaseService.setLocalExpiryRemindersEnabled(false);
      throw StateError('Notification permission was not granted');
    }
    await sync(items);
  }

  Future<void> sync(Iterable<GroceryItem> items) async {
    if (!DistributionConfig.isSideStore ||
        !LocalDatabaseService.localExpiryRemindersEnabled) {
      return;
    }
    await initialize();
    await cancelAll();

    final now = DateTime.now();
    final today = GroceryItem.normalizeDateOnly(now);
    final daysBefore = LocalDatabaseService.localExpiryReminderDays;
    final activeItems =
        items
            .where((item) => !item.isConsumed)
            .where((item) => !item.expiryDate.isBefore(today))
            .toList()
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    for (final item in activeItems.take(_maxScheduledItems)) {
      final scheduled = DateTime(
        item.expiryDate.year,
        item.expiryDate.month,
        item.expiryDate.day,
        9,
      ).subtract(Duration(days: daysBefore));
      if (!scheduled.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        _notificationId(item),
        _titleFor(item),
        _bodyFor(item),
        tz.TZDateTime.from(scheduled, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!DistributionConfig.isSideStore) return;
    await initialize();
    await _plugin.cancelAll();
  }

  int _notificationId(GroceryItem item) =>
      100000 +
      item.id.codeUnits.fold(0, (sum, value) => (sum + value) % 800000);

  String _titleFor(GroceryItem item) {
    final days = item.daysUntilExpiry;
    if (days == 0) return '${item.name} expires today';
    if (days == 1) return '${item.name} expires tomorrow';
    return '${item.name} expires in ${max(days, 0)} days';
  }

  String _bodyFor(GroceryItem item) {
    final location = item.location?.trim();
    final place = location == null || location.isEmpty ? '' : ' in $location';
    return 'Use ${item.name}$place before ${GroceryItem.formatDateOnly(item.expiryDate)}.';
  }
}
