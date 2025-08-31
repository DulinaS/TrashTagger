// lib/services/notification_service.dart - Complete Flutter Implementation
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/challenges/challenges_screen.dart';
import '../screens/challenges/cleanup_proof_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/badges_screen.dart';
import '../screens/profile/leaderboard_screen.dart';
import '../screens/map/report_detail_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../models/trash_report_model.dart';
import '../models/notification_model.dart';

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
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize notification service: $e');
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
      'Notification permission status: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('User denied notification permissions');
      _showPermissionDialog();
    }
  }

  static Future<void> _updateFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
        debugPrint('FCM Token updated: ${token.substring(0, 20)}...');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((String token) {
        _sendTokenToBackend(token);
      });
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
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
      debugPrint('Failed to send token to backend: $e');
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
    debugPrint('Received foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    _navigateBasedOnNotification(message.data);
  }

  static Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification');
      // Delay navigation to ensure app is fully loaded
      Future.delayed(Duration(seconds: 2), () {
        _navigateBasedOnNotification(initialMessage.data);
      });
    }
  }

  // ================================
  // LOCAL NOTIFICATION DISPLAY
  // ================================

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Get notification type for proper channel
    final notificationType = message.data['type'] ?? 'general';
    String channelId = _getChannelId(notificationType);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: _getImportance(notificationType),
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      color: const Color(0xFF4CAF50),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('default'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    final platformDetails = NotificationDetails(
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
      debugPrint('Local notification tapped: ${response.payload}');
      // You could parse the payload and navigate accordingly
    }
  }

  // ================================
  // NOTIFICATION CHANNELS (ANDROID)
  // ================================

  static Future<void> _createNotificationChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (plugin == null) return;

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
      await plugin.createNotificationChannel(channel);
    }
  }

  // ================================
  // NAVIGATION HANDLING
  // ================================

  static void _navigateBasedOnNotification(Map<String, dynamic> data) {
    if (_context == null) return;

    final action = data['action'] as String?;
    final type = data['type'] as String?;

    debugPrint(
      'Navigating based on notification - Action: $action, Type: $type',
    );

    switch (action) {
      case 'open_challenge_details':
        _navigateToChallenge(data['reportId']);
        break;
      case 'open_my_challenges':
        _navigateToChallenges();
        break;
      case 'open_challenge_proof':
      case 'resubmit_proof':
        _navigateToProofSubmission(data['reportId']);
        break;
      case 'view_report_status':
      case 'view_completed_report':
      case 'view_challenge_result':
        _navigateToReport(data['reportId']);
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
      case 'open_notifications':
        _navigateToNotifications();
        break;
      default:
        _navigateToHome();
    }
  }

  static void _navigateToChallenge(String? reportId) {
    if (reportId == null || _context == null) return;

    Navigator.of(_context!).push(
      MaterialPageRoute(
        builder: (context) => FutureBuilder<TrashReportModel?>(
          future: _getReportById(reportId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: Text('Loading...')),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return ReportDetailScreen(report: snapshot.data!);
            }

            return Scaffold(
              appBar: AppBar(title: Text('Error')),
              body: Center(child: Text('Could not load challenge details')),
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

    _getReportById(reportId).then((report) {
      if (report != null && _context != null) {
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => CleanupProofScreen(challenge: report),
          ),
        );
      }
    });
  }

  static void _navigateToReport(String? reportId) {
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

  static void _navigateToNotifications() {
    if (_context == null) return;
    Navigator.of(
      _context!,
    ).push(MaterialPageRoute(builder: (context) => NotificationsScreen()));
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

  static String _getChannelId(String notificationType) {
    switch (notificationType) {
      case 'new_challenge':
      case 'challenge_accepted':
      case 'challenge_reminder':
        return 'challenges';
      case 'badge_earned':
      case 'level_up':
      case 'points_awarded':
        return 'achievements';
      case 'leaderboard_update':
        return 'leaderboard';
      default:
        return 'general';
    }
  }

  static String _getChannelName(String channelId) {
    switch (channelId) {
      case 'challenges':
        return 'Challenge Notifications';
      case 'achievements':
        return 'Achievement Notifications';
      case 'leaderboard':
        return 'Leaderboard Notifications';
      default:
        return 'General Notifications';
    }
  }

  static String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'challenges':
        return 'Notifications about cleanup challenges and opportunities';
      case 'achievements':
        return 'Notifications about badges, level ups, and achievements';
      case 'leaderboard':
        return 'Notifications about leaderboard updates and rankings';
      default:
        return 'General app notifications';
    }
  }

  static Importance _getImportance(String notificationType) {
    switch (notificationType) {
      case 'new_challenge':
      case 'badge_earned':
      case 'level_up':
      case 'verification_result':
        return Importance.high;
      case 'challenge_reminder':
      case 'leaderboard_update':
        return Importance.defaultImportance;
      default:
        return Importance.low;
    }
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
      if (_context == null) return;

      final userId = Provider.of<AuthProvider>(
        _context!,
        listen: false,
      ).user?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'settings.challengeNotifications': challengeNotifications,
        'settings.achievementNotifications': achievementNotifications,
        'settings.leaderboardNotifications': leaderboardNotifications,
      });
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  // ================================
  // TEST NOTIFICATION (FOR DEBUGGING)
  // ================================

  static Future<void> sendTestNotificationDebugging() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Test Notification',
        'This is a test notification from TrashTagger',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }

  // ================================
  // TESTING METHODS
  // ================================

  static Future<void> sendTestNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'Test notification',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF4CAF50),
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Test Notification 🧪',
        'This is a test notification from TrashTagger',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      rethrow;
    }
  }

  static Future<void> sendTestAchievementNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'achievements',
        'Achievement Notifications',
        channelDescription: 'Test achievement notification',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: Color(0xFF4CAF50),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'achievement.wav',
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'New Badge Earned! 🏆',
        'You\'ve earned "Test Badge" - Keep up the great work!',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error sending achievement notification: $e');
      rethrow;
    }
  }

  static Future<void> sendTestChallengeNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'challenges',
        'Challenge Notifications',
        channelDescription: 'Test challenge notification',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: Color(0xFF4CAF50),
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'New Cleanup Challenge Available!',
        'Recyclable cleanup needed nearby - Test Location',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error sending challenge notification: $e');
      rethrow;
    }
  }

  // Test method to check notification status
  static Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final token = await _firebaseMessaging.getToken();
      final settings = await _firebaseMessaging.getNotificationSettings();

      return {
        'hasToken': token != null,
        'tokenPreview': token?.substring(0, 20) ?? 'No token',
        'permissionStatus': settings.authorizationStatus.name,
        'initialized': _initialized,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'hasToken': false,
        'permissionStatus': 'unknown',
        'initialized': _initialized,
      };
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

  // ================================
  // BADGE COUNT MANAGEMENT
  // ================================

  static Future<void> updateBadgeCount(int count) async {
    try {
      if (Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        // iOS badge count is handled by Firebase automatically
      }
    } catch (e) {
      debugPrint('Error updating badge count: $e');
    }
  }

  static Future<void> clearBadgeCount() async {
    await updateBadgeCount(0);
  }

  // ================================
  // NOTIFICATION HISTORY
  // ================================

  static Stream<List<NotificationModel>> getNotificationHistory(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    NotificationModel.fromMap({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}
