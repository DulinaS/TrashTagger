// lib/screens/test/notification_test_screen.dart - Fixed version
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../themes/app_theme.dart';

class NotificationTestScreen extends StatefulWidget {
  @override
  _NotificationTestScreenState createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _isLoading = false;
  String _testResult = '';
  Map<String, dynamic> _systemStatus = {};

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
  }

  Future<void> _checkSystemStatus() async {
    final status = await NotificationService.getNotificationStatus();
    setState(() {
      _systemStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        title: Text('Test Notifications'),
        backgroundColor: AppTheme.gradientEnd,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            SizedBox(height: 24),

            // Local Notification Tests
            _buildTestSection('Local Notification Tests', [
              _buildTestButton(
                'Test Basic Notification',
                'Send a simple local notification',
                () => _testLocalNotification(),
              ),
              _buildTestButton(
                'Test Achievement Notification',
                'Simulate badge earned notification',
                () => _testAchievementNotification(),
              ),
              _buildTestButton(
                'Test Challenge Notification',
                'Simulate new challenge notification',
                () => _testChallengeNotification(),
              ),
            ]),

            SizedBox(height: 24),

            // Cloud Function Tests
            _buildTestSection('Cloud Function Tests', [
              _buildTestButton(
                'Test FCM Token Update',
                'Verify token is saved to backend',
                () => _testFCMTokenUpdate(),
              ),
              _buildTestButton(
                'Test Nearby Users Notification',
                'Test backend notification sending',
                () => _testNearbyUsersNotification(),
              ),
            ]),

            SizedBox(height: 24),

            // Integration Tests
            _buildTestSection('Integration Tests', [
              _buildTestButton(
                'Create Test Report',
                'Create a report to trigger notifications',
                () => _createTestReport(),
              ),
              _buildTestButton(
                'Test Badge Award',
                'Manually trigger badge award',
                () => _testBadgeAward(),
              ),
            ]),

            SizedBox(height: 24),

            // Test Results
            if (_testResult.isNotEmpty) _buildTestResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.infoBlue),
                SizedBox(width: 8),
                Text('System Status', style: AppTheme.headlineMedium),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _checkSystemStatus,
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatusRow(
              'Permissions',
              _systemStatus['permissionStatus'] ?? 'Unknown',
            ),
            _buildStatusRow(
              'FCM Token',
              _systemStatus['hasToken'] == true ? 'Available' : 'Missing',
            ),
            _buildStatusRow(
              'Service Initialized',
              _systemStatus['initialized'] == true ? 'Yes' : 'No',
            ),
            _buildStatusRow('Platform', Platform.operatingSystem),
            if (_systemStatus['tokenPreview'] != null) ...[
              SizedBox(height: 8),
              Text(
                'Token Preview: ${_systemStatus['tokenPreview']}...',
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status) {
    Color statusColor = AppTheme.textSecondary;
    if (status.toLowerCase().contains('authorized') ||
        status == 'Available' ||
        status == 'Yes') {
      statusColor = AppTheme.accentAmber;
    } else if (status.toLowerCase().contains('denied') ||
        status == 'Missing' ||
        status == 'No') {
      statusColor = AppTheme.errorRed;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Text(
            status,
            style: AppTheme.bodyMedium.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection(String title, List<Widget> tests) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.headlineMedium),
            SizedBox(height: 16),
            ...tests,
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    String description,
    VoidCallback onPressed,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: Card(
        color: AppTheme.gradientEnd.withOpacity(0.1),
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.labelMedium),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.play_arrow, color: AppTheme.gradientEnd),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestResults() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, color: AppTheme.infoBlue),
                SizedBox(width: 8),
                Text('Test Results', style: AppTheme.headlineMedium),
                Spacer(),
                TextButton(
                  onPressed: () => setState(() => _testResult = ''),
                  child: Text('Clear'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _testResult.isEmpty ? 'No test results yet' : _testResult,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // TEST METHODS
  // ================================

  Future<void> _testLocalNotification() async {
    setState(() => _isLoading = true);

    try {
      await NotificationService.sendTestNotification();
      _setTestResult('Local notification sent successfully!');
    } catch (e) {
      _setTestResult('Local notification failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testAchievementNotification() async {
    setState(() => _isLoading = true);

    try {
      await NotificationService.sendTestAchievementNotification();
      _setTestResult('Achievement notification sent successfully!');
    } catch (e) {
      _setTestResult('Achievement notification failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testChallengeNotification() async {
    setState(() => _isLoading = true);

    try {
      await NotificationService.sendTestChallengeNotification();
      _setTestResult('Challenge notification sent successfully!');
    } catch (e) {
      _setTestResult('Challenge notification failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testFCMTokenUpdate() async {
    setState(() => _isLoading = true);

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'updateFCMToken',
        );
        final result = await callable.call({
          'token': token,
          'platform': Platform.operatingSystem,
        });

        _setTestResult(
          'FCM Token updated successfully!\nToken: ${token.substring(0, 50)}...\nResult: ${result.data}',
        );
      } else {
        _setTestResult('No FCM token available');
      }
    } catch (e) {
      _setTestResult('FCM token update failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testNearbyUsersNotification() async {
    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'notifyNearbyUsers',
      );
      final result = await callable.call({
        'reportLocation': {'latitude': 6.9271, 'longitude': 79.8612},
        'reportId': 'test_report_${DateTime.now().millisecondsSinceEpoch}',
        'reportData': {
          'reporterId': 'test_user',
          'trashType': 'recyclable',
          'severity': 'medium',
          'address': 'Test Location, Colombo',
          'imageURL': 'https://example.com/test.jpg',
        },
      });

      _setTestResult('Nearby users notification sent!\nResult: ${result.data}');
    } catch (e) {
      _setTestResult('Nearby users notification failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _createTestReport() async {
    setState(() => _isLoading = true);

    try {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).user?.uid;
      if (userId == null) {
        _setTestResult('User not authenticated');
        setState(() => _isLoading = false);
        return;
      }

      // Create a test report in Firestore
      final testReport = {
        'reporterId': userId,
        'imageURL':
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
        'location': GeoPoint(6.9271, 79.8612), // Colombo coordinates
        'address': 'Test Location, Colombo, Sri Lanka',
        'trashType': 'general',
        'severity': 'medium',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'estimatedEffort': '10-20min',
        'safetyWarnings': [],
        'votes': {'upvotes': 0, 'downvotes': 0, 'voters': []},
        'flagged': false,
        'flagReasons': [],
      };

      final docRef = await FirebaseFirestore.instance
          .collection('trashReports')
          .add(testReport);

      _setTestResult(
        'Test report created!\nReport ID: ${docRef.id}\nThis should trigger AI analysis and notifications.',
      );
    } catch (e) {
      _setTestResult('Test report creation failed: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testBadgeAward() async {
    setState(() => _isLoading = true);

    try {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).user?.uid;
      if (userId == null) {
        _setTestResult('User not authenticated');
        setState(() => _isLoading = false);
        return;
      }

      // Manually award a test badge
      final testBadgeId = 'test_badge_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'badges': FieldValue.arrayUnion([testBadgeId]),
        'totalPoints': FieldValue.increment(50),
      });

      _setTestResult(
        'Test badge awarded!\nBadge ID: $testBadgeId\nThis should trigger badge notification.',
      );
    } catch (e) {
      _setTestResult('Badge award test failed: $e');
    }

    setState(() => _isLoading = false);
  }

  void _setTestResult(String result) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _testResult = '$timestamp: $result\n\n$_testResult';
    });
  }
}
