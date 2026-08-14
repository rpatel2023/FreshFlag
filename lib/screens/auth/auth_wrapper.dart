import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/fcm_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../viewmodels/grocery_viewmodel.dart';
import '../../viewmodels/household_viewmodel.dart';
import '../household_setup_screen.dart';
import '../main_app_screen.dart';
import 'login_screen.dart';

/// Routes from Firebase authentication into household-owned inventory.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _loadedUid;
  String? _boundHouseholdId;

  @override
  Widget build(BuildContext context) {
    final authService = context.read<FirebaseAuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          if (_loadedUid != null) _resetSessionState();
          return const LoginScreen();
        }

        final household = context.watch<HouseholdViewModel>();
        if (_loadedUid != user.uid) {
          _loadedUid = user.uid;
          _boundHouseholdId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await FCMService.instance.syncRegistrationForCurrentUser();
            if (!mounted) return;
            await household.initializeForUser(user.uid);
          });
        }

        if (household.isLoading && household.current == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (household.current == null) {
          return const HouseholdSetupScreen();
        }

        final householdId = household.current!.id;
        if (_boundHouseholdId != householdId) {
          _boundHouseholdId = householdId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<GroceryViewModel>().bindHousehold(householdId);
          });
        }

        return const MainAppScreen();
      },
    );
  }

  void _resetSessionState() {
    _loadedUid = null;
    _boundHouseholdId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HouseholdViewModel>().reset();
      context.read<GroceryViewModel>().reset();
    });
  }
}
