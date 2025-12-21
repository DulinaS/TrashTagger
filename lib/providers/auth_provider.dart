// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  UserModel? _userData;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.signInWithEmail(email, password);
      _user = result?.user;

      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.signUpWithEmail(email, password, name);
      _user = result?.user;

      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('🚪 AuthProvider.signOut() called');
      debugPrint('🚪 Current user before signout: ${_user?.uid}');

      // Cancel any active Firestore listeners first
      await _cancelAllListeners();

      await _authService.signOut();
      _user = null;
      _userData = null;

      debugPrint('🚪 User set to null, calling notifyListeners()');
      notifyListeners();
      debugPrint('🚪 notifyListeners() completed');
    } catch (e) {
      debugPrint('❌ SignOut error: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // Add this method to properly cleanup
  Future<void> _cancelAllListeners() async {
    // This will be called when signing out to prevent errors
    try {
      // Any cleanup needed
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
