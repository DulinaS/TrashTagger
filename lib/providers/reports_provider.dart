// lib/providers/reports_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trash_report_model.dart';
import '../services/firestore_service.dart';

class ReportsProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<TrashReportModel> _nearbyReports = [];
  List<TrashReportModel> _userReports = [];
  List<TrashReportModel> _availableChallenges = [];
  bool _isLoading = false;
  String? _error;

  List<TrashReportModel> get nearbyReports => _nearbyReports;
  List<TrashReportModel> get userReports => _userReports;
  List<TrashReportModel> get availableChallenges => _availableChallenges;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNearbyReports(GeoPoint location, double radius) async {
    try {
      _isLoading = true;
      notifyListeners();

      _firestoreService.getNearbyReports(location, radius).listen((reports) {
        _nearbyReports = reports;
        _availableChallenges = reports
            .where((r) => r.status == 'verified')
            .toList();
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createReport(TrashReportModel report) async {
    try {
      final reportId = await _firestoreService.createReport(report);
      return reportId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptChallenge(String reportId, String userId) async {
    try {
      await _firestoreService.acceptChallenge(reportId, userId);

      // Update local state
      final reportIndex = _availableChallenges.indexWhere(
        (r) => r.id == reportId,
      );
      if (reportIndex != -1) {
        _availableChallenges.removeAt(reportIndex);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> submitProof(String reportId, String proofURL) async {
    try {
      await _firestoreService.submitProof(reportId, proofURL);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> voteOnReport(
    String reportId,
    String userId,
    bool isUpvote,
  ) async {
    try {
      await _firestoreService.voteOnReport(reportId, userId, isUpvote);
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
