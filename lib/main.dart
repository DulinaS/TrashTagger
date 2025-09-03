// lib/main.dart - Fixed version
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/reports_provider.dart';
import 'screens/home/main_ navigation_screen.dart';
import 'services/notification_service.dart';
import 'screens/auth/auth_wrapper.dart';
import 'themes/app_theme.dart';

final GlobalKey<MainNavigationScreenState> mainNavKey =
    GlobalKey<MainNavigationScreenState>();

// Global handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");

  // You can add custom background processing here
  // For example, update local database, show notification, etc.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  runApp(TrashTaggerApp());
}

class TrashTaggerApp extends StatefulWidget {
  @override
  _TrashTaggerAppState createState() => _TrashTaggerAppState();
}

class _TrashTaggerAppState extends State<TrashTaggerApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        NotificationService.cleanup();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeNotifications() async {
    // Wait for the widget tree to be built
    await Future.delayed(Duration(milliseconds: 500));

    if (navigatorKey.currentContext != null) {
      await NotificationService.initialize(navigatorKey.currentContext!);
    }
  }

  void _handleAppResumed() {
    // Clear badge count when app is opened
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _handleAppPaused() {
    // App went to background
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ReportsProvider()),
      ],
      child: MaterialApp(
        title: 'TrashTagger',
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Initialize notifications once user is authenticated
            if (authProvider.user != null && !authProvider.isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NotificationService.initialize(context);
                // Load user data when authenticated
                Provider.of<UserProvider>(
                  context,
                  listen: false,
                ).loadCurrentUser(authProvider.user!.uid);
              });
            }

            if (authProvider.isLoading) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryGreen,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Loading TrashTagger...'),
                    ],
                  ),
                ),
              );
            }

            if (authProvider.user == null) {
              return AuthWrapper();
            }

            return MainNavigationScreen(key: mainNavKey);
          },
        ),
      ),
    );
  }
}
