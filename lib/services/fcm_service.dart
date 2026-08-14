import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Client-side Firebase Cloud Messaging plumbing.
///
/// FreshFlag never sends FCM messages from the client. Device-token persistence
/// and server-side delivery are added with the household notification backend.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  static FCMService get instance => _instance;

  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _currentToken;
  bool _isInitialized = false;

  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await requestPermissions();
      _currentToken = await _fcm.getToken();

      _fcm.onTokenRefresh.listen((token) {
        _currentToken = token;
        debugPrint('FCM token refreshed.');
        // Phase 6 persists this under users/{uid}/devices/{deviceId}.
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('Foreground FCM message: ${message.messageId}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('Opened from FCM message: ${message.messageId}');
        // Phase 7 adds notification deep linking.
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
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

  Future<void> subscribeToTopic(String topic) => _fcm.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);

  /// Retained temporarily for the inherited diagnostic widget.
  ///
  /// Client-side message sending is deliberately disabled because an FCM
  /// server credential must never be shipped inside the application.
  Future<bool> sendTestNotification({
    required String item,
    required String daysLeft,
    String? customUserId,
  }) async {
    debugPrint(
      'Client-side FCM sending is disabled. '
      'item=$item daysLeft=$daysLeft user=$customUserId',
    );
    return false;
  }

  /// Compatibility no-op for inherited callers while Supabase is removed.
  /// Device-token persistence moves to Firestore in the backend notification
  /// phase rather than another database.
  Future<void> storeTokenInSupabase(String? userId) async {
    debugPrint('Supabase token persistence removed; user=$userId');
  }
}
