import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_target.dart';
import 'firebase_auth_service.dart';

/// Client-side Firebase Cloud Messaging registration and tap plumbing.
///
/// FreshFlag never sends FCM messages from the client. Each app installation
/// owns a stable local device ID; its current FCM registration token is stored
/// at `users/{uid}/devices/{deviceId}` for backend delivery.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  static FCMService get instance => _instance;

  FCMService._internal();

  static const _deviceIdPreferenceKey = 'freshflag_device_id';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;
  final StreamController<NotificationTarget> _navigationController =
      StreamController<NotificationTarget>.broadcast();

  String? _currentToken;
  bool _isInitialized = false;
  NotificationTarget? _pendingNavigationTarget;

  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;
  Stream<NotificationTarget> get navigationTargets =>
      _navigationController.stream;

  NotificationTarget? takePendingNavigationTarget() {
    final target = _pendingNavigationTarget;
    _pendingNavigationTarget = null;
    return target;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _currentToken = await _fcm.getToken();

      _fcm.onTokenRefresh.listen((token) async {
        _currentToken = token;
        debugPrint('FCM token refreshed.');
        await syncRegistrationForCurrentUser(token: token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('Foreground FCM message: ${message.messageId}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_queueNavigationFromMessage);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final target = NotificationTarget.fromData(initialMessage.data);
        if (target != null) {
          _pendingNavigationTarget = target;
        }
        debugPrint('Started from FCM message: ${initialMessage.messageId}');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('FCM initialization failed: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      _currentToken = await _fcm.getToken();
      return _currentToken;
    } catch (e) {
      debugPrint('FCM token retrieval failed: $e');
      return null;
    }
  }

  Future<void> syncRegistrationForCurrentUser({String? token}) async {
    final uid = _auth.currentUserId;
    if (uid == null) return;

    try {
      final currentToken = token ?? _currentToken ?? await _fcm.getToken();
      if (currentToken == null || currentToken.isEmpty) return;
      _currentToken = currentToken;

      final deviceId = await _getOrCreateDeviceId();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .set(
        {
          'deviceId': deviceId,
          'fcmToken': currentToken,
          'platform': _platformName,
          'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCM registration sync failed: $e');
    }
  }

  Future<void> setPushEnabledForCurrentUser(bool enabled) async {
    final uid = _auth.currentUserId;
    if (uid == null) return;

    if (enabled) {
      final granted = await requestPermissions();
      if (!granted) {
        throw StateError('Notification permission was not granted');
      }
      await syncRegistrationForCurrentUser();
    }

    await _firestore.collection('users').doc(uid).set(
      {
        'notificationsEnabled': enabled,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> removeCurrentUserRegistration() async {
    final uid = _auth.currentUserId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_deviceIdPreferenceKey);
      if (deviceId == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .delete();
    } catch (e) {
      debugPrint('FCM registration removal failed: $e');
    }
  }

  void _queueNavigationFromMessage(RemoteMessage message) {
    final target = NotificationTarget.fromData(message.data);
    if (target == null) return;
    _pendingNavigationTarget = target;
    _navigationController.add(target);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdPreferenceKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await prefs.setString(_deviceIdPreferenceKey, id);
    return id;
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
