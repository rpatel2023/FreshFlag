import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_brand.dart';
import 'config/distribution_config.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'services/fcm_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_database_service.dart';
import 'theme/theme_provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/grocery_viewmodel.dart';
import 'viewmodels/household_viewmodel.dart';

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

Future<void> _initializeFcmAfterLaunch() async {
  try {
    await FCMService.instance.initialize();
  } catch (e) {
    debugPrint('FCM service initialization failed: $e');
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

  if (DistributionConfig.supportsRemotePush) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('FCM background handler setup failed: $e');
    }
  }

  // Render before any optional messaging work. In a SideStore build, FCM is
  // intentionally disabled because Personal-Team signing is not a supported
  // APNs delivery path. In a standard build, initialize FCM after the first
  // frame so token acquisition can never hold the native iOS launch screen.
  runApp(const FreshFlagApp());

  if (DistributionConfig.supportsRemotePush) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeFcmAfterLaunch());
    });
  }
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
        ChangeNotifierProvider(create: (_) => HouseholdViewModel()),
        ChangeNotifierProvider(create: (_) => GroceryViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppBrand.name,
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
