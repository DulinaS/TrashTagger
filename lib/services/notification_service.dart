// lib/services/notification_service.dart - Flutter Implementation
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/challenges/challenges_screen.dart';
import '../screens/challenges/cleanup_proof_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/badges_screen.dart';
import '../screens/profile/leaderboard_screen.dart';
import '../screens/map/report_detail_screen.dart';
import '../models/trash_report_model.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static BuildContext? _context;
  static bool _initialized = false;

  // ================================
  // INITIALIZATION
  // ================================

  static Future<void> initialize(BuildContext context) async {
    if (_initialized) return;

    _context = context;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Get and update FCM token
      await _updateFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Set up notification channels (Android)
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      _initialized = true;
      debugPrint('🔔 Notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize notification service: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  static Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      announcement: false,
    );

    debugPrint(
      '🔐 Notification permission status: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️ User denied notification permissions');
      _showPermissionDialog();
    }
  }

  static Future<void> _updateFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
        debugPrint('📲 FCM Token updated: ${token.substring(0, 20)}...');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((String token) {
        _sendTokenToBackend(token);
      });
    } catch (e) {
      debugPrint('❌ Failed to update FCM token: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final callable = _functions.httpsCallable('updateFCMToken');
      await callable.call({
        'token': token,
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      debugPrint('❌ Failed to send token to backend: $e');
    }
  }

  // ================================
  // MESSAGE HANDLERS
  // ================================

  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    _checkInitialMessage();
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Received foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
    _navigateBasedOnNotification(message.data);
  }

  static Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App opened from terminated state via notification');
      _navigateBasedOnNotification(initialMessage.data);
    }
  }

  // ================================
  // LOCAL NOTIFICATION DISPLAY
  // ================================

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'general',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: message.data.toString(),
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // Parse payload and navigate
      debugPrint('Local notification tapped: ${response.payload}');
    }
  }

  // ================================
  // NOTIFICATION CHANNELS (ANDROID)
  // ================================

  static Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'challenges',
        'Challenge Notifications',
        description: 'Notifications about cleanup challenges',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
      AndroidNotificationChannel(
        'achievements',
        'Achievement Notifications',
        description: 'Notifications about badges and level ups',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('achievement'),
      ),
      AndroidNotificationChannel(
        'leaderboard',
        'Leaderboard Notifications',
        description: 'Notifications about leaderboard updates',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'general',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.defaultImportance,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  // ================================
  // NAVIGATION HANDLING
  // ================================

  static void _navigateBasedOnNotification(Map<String, dynamic> data) {
    if (_context == null) return;

    final action = data['action'] as String?;
    //final type = data['type'] as String?;

    switch (action) {
      case 'open_challenge_details':
        _navigateToChallenge(data['reportId']);
        break;
      case 'open_my_challenges':
        _navigateToChallenges();
        break;
      case 'open_challenge_proof':
        _navigateToProofSubmission(data['reportId']);
        break;
      case 'view_report_status':
      case 'view_completed_report':
        _navigateToReport(data['reportId']);
        break;
      case 'resubmit_proof':
        _navigateToProofSubmission(data['reportId']);
        break;
      case 'view_badges':
        _navigateToBadges();
        break;
      case 'view_profile':
        _navigateToProfile();
        break;
      case 'view_leaderboard':
        _navigateToLeaderboard();
        break;
      case 'view_challenge_result':
        _navigateToChallenge(data['reportId']);
        break;
      default:
        _navigateToHome();
    }
  }

  static void _navigateToChallenge(String? reportId) {
    if (reportId == null || _context == null) return;

    // Navigate to specific challenge/report details
    Navigator.of(_context!).push(
      MaterialPageRoute(
        builder: (context) => FutureBuilder<TrashReportModel?>(
          future: _getReportById(reportId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return ReportDetailScreen(report: snapshot.data!);
            }
            return Scaffold(
              appBar: AppBar(title: Text('Loading...')),
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  static void _navigateToChallenges() {
    if (_context == null) return;
    Navigator.of(
      _context!,
    ).push(MaterialPageRoute(builder: (context) => ChallengesScreen()));
  }

  static void _navigateToProofSubmission(String? reportId) {
    if (reportId == null || _context == null) return;

    // Navigate to proof submission screen
    _getReportById(reportId).then((report) {
      if (report != null) {
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => CleanupProofScreen(challenge: report),
          ),
        );
      }
    });
  }

  static void _navigateToReport(String? reportId) {
    if (reportId == null) return;
    _navigateToChallenge(reportId); // Same as challenge navigation
  }

  static void _navigateToBadges() {
    if (_context == null) return;
    Navigator.of(
      _context!,
    ).push(MaterialPageRoute(builder: (context) => BadgesScreen()));
  }

  static void _navigateToProfile() {
    if (_context == null) return;
    Navigator.of(
      _context!,
    ).push(MaterialPageRoute(builder: (context) => ProfileScreen()));
  }

  static void _navigateToLeaderboard() {
    if (_context == null) return;
    Navigator.of(
      _context!,
    ).push(MaterialPageRoute(builder: (context) => LeaderboardScreen()));
  }

  static void _navigateToHome() {
    if (_context == null) return;
    // Navigate to main tab or home screen
    Navigator.of(_context!).popUntil((route) => route.isFirst);
  }

  // ================================
  // UTILITY METHODS
  // ================================

  static Future<TrashReportModel?> _getReportById(String reportId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trashReports')
          .doc(reportId)
          .get();

      if (doc.exists) {
        return TrashReportModel.fromMap({
          '_documentId': doc.id,
          ...doc.data()!,
        });
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
    }
    return null;
  }

  static void _showPermissionDialog() {
    if (_context == null) return;

    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: Text('Enable Notifications'),
        content: Text(
          'Get notified about new cleanup challenges near you and track your progress. '
          'You can change this anytime in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPermissions();
            },
            child: Text('Enable'),
          ),
        ],
      ),
    );
  }

  // ================================
  // NOTIFICATION PREFERENCES
  // ================================

  static Future<void> updateNotificationPreferences({
    required bool challengeNotifications,
    required bool achievementNotifications,
    required bool leaderboardNotifications,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(Provider.of<AuthProvider>(_context!, listen: false).user?.uid)
          .update({
            'settings.challengeNotifications': challengeNotifications,
            'settings.achievementNotifications': achievementNotifications,
            'settings.leaderboardNotifications': leaderboardNotifications,
          });
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  // ================================
  // CLEANUP
  // ================================

  static Future<void> cleanup() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        final callable = _functions.httpsCallable('removeFCMToken');
        await callable.call({'token': token});
      }
    } catch (e) {
      debugPrint('Error during notification cleanup: $e');
    }
  }
}
