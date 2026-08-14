import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'services/fcm_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_database_service.dart';
import 'services/notification_service.dart';
import 'theme/theme_provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/grocery_viewmodel.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      debugPrint('Firebase init error in background: $e');
    }
  }
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await LocalDatabaseService.initialize();
  } catch (e) {
    debugPrint('Local preference initialization failed: $e');
  }

  try {
    await _ensureFirebaseInitialized();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM background handler setup failed: $e');
  }

  try {
    await FCMService.instance.initialize();
  } catch (e) {
    debugPrint('FCM service initialization failed: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification service initialization failed: $e');
  }

  runApp(const FreshFlagApp());
}

void main() async {
  await _initializeApp();
}

class FreshFlagApp extends StatelessWidget {
  const FreshFlagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuthService>.value(
          value: FirebaseAuthService.instance,
        ),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => GroceryViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'FreshFlag',
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
