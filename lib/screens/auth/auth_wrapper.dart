import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/firebase_auth_service.dart';
import '../../viewmodels/grocery_viewmodel.dart';
import '../home_screen.dart';
import 'login_screen.dart';

/// Routes between authentication and the signed-in inventory experience.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _loadedUserId;

  void _syncInventoryFor(User? user) {
    final groceryViewModel = context.read<GroceryViewModel>();

    if (user == null) {
      if (_loadedUserId != null) {
        _loadedUserId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) groceryViewModel.reset();
        });
      }
      return;
    }

    if (_loadedUserId == user.uid) return;
    _loadedUserId = user.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) groceryViewModel.loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<FirebaseAuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        _syncInventoryFor(user);

        if (user != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
