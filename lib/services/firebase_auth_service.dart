import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Authentication service for FreshFlag.
///
/// Phase 1 intentionally supports authenticated user sessions only. Anonymous
/// demo sign-in was removed so inventory behavior cannot silently bypass the
/// real authentication flow.
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  static FirebaseAuthService get instance => _instance;

  FirebaseAuthService._internal() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveAuthToken();
      } else {
        await _clearAuthToken();
      }
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _tokenKey = 'auth_token';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _saveAuthToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token != null) {
        final prefs = await _preferences;
        await prefs.setString(_tokenKey, token);
      }
    } catch (e) {
      debugPrint('Error saving auth token: $e');
    }
  }

  Future<void> _clearAuthToken() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('Error clearing auth token: $e');
    }
  }

  /// Return whether Firebase currently has an authenticated user.
  ///
  /// SharedPreferences is kept only as a cached token store for now; token
  /// presence is not treated as proof that a session is valid.
  Future<bool> hasValidToken() async => _auth.currentUser != null;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<User?> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (displayName != null && result.user != null) {
        await result.user!.updateDisplayName(displayName);
        await result.user!.reload();
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Account creation failed: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _clearAuthToken();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-credential':
        return 'The credential is malformed or has expired.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      case 'provider-already-linked':
        return 'This provider is already linked to your account.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
        return 'Authentication failed. Please try again.';
    }
  }
}
