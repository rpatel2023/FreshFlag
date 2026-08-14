import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/firebase_auth_service.dart';
import '../../viewmodels/grocery_viewmodel.dart';
import '../main_app_screen.dart';
import 'login_screen.dart';

/// Routes between authentication and the app from the real Firebase session.
///
/// Inventory is loaded when an authenticated user becomes active and cleared
/// when the session ends so one user's data can never leak into another user's
/// in-memory state.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _loadedUid;

  @override
  Widget build(BuildContext context) {
    final authService = context.read<FirebaseAuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          if (_loadedUid != null) {
            _loadedUid = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.read<GroceryViewModel>().reset();
            });
          }
          return const LoginScreen();
        }

        if (_loadedUid != user.uid) {
          _loadedUid = user.uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<GroceryViewModel>().loadItems();
          });
        }

        return const MainAppScreen();
      },
    );
  }
}
