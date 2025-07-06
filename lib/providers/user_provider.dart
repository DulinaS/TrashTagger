//lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

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

  Future<void> loadCurrentUser(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await _firestoreService.getUser(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
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
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
