// lib/main.dart - Modern Design with Updated Theme System (Updated)
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
    await Future.delayed(const Duration(milliseconds: 500));

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
              return _buildModernSplashScreen();
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

  Widget _buildModernSplashScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryEmerald.withOpacity(0.1),
              AppTheme.primaryTeal.withOpacity(0.05),
              AppTheme.backgroundPrimary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryEmerald.withOpacity(
                              0.4 * value,
                            ),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // App Title with Gradient
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  'TrashTagger',
                  style: AppTheme.displayMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Clean up the world, one report at a time',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Modern Loading Indicator
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return TweenAnimationBuilder(
                      duration: const Duration(seconds: 3),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Container(
                          width: constraints.maxWidth * value,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Loading Text
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Text(
                      'Loading TrashTagger...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
