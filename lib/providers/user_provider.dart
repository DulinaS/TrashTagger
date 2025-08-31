// lib/providers/user_provider.dart - Fixed with updateAuth method
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _currentUser;
  List<UserModel> _leaderboard = [];
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  List<UserModel> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Required method for ChangeNotifierProxyProvider
  void updateAuth(AuthProvider authProvider) {
    // Load user data when auth state changes
    if (authProvider.user != null &&
        _currentUser?.id != authProvider.user!.uid) {
      loadCurrentUser(authProvider.user!.uid);
    } else if (authProvider.user == null) {
      // Clear user data when signed out
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> loadCurrentUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _firestoreService.getUser(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading user: $e');
    }
  }

  Future<void> loadLeaderboard(String period) async {
    try {
      _isLoading = true;
      notifyListeners();

      _leaderboard = await _firestoreService.getLeaderboard(period);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading leaderboard: $e');
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _firestoreService.updateUser(user);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('Error updating user: $e');
    }
  }

  // Refresh current user data
  Future<void> refreshUser() async {
    if (_currentUser != null) {
      await loadCurrentUser(_currentUser!.id);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data (useful for sign out)
  void clearData() {
    _currentUser = null;
    _leaderboard = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
