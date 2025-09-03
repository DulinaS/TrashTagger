// lib/screens/home/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../themes/app_theme.dart';
import '../map/map_screen.dart';
import '../challenges/challenges_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import 'home_screen.dart';
import '../report/camera_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({Key? key, this.initialIndex = 0})
    : super(key: key);

  @override
  MainNavigationScreenState createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  int _unreadNotificationCount = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    MapScreen(),
    CameraScreen(),
    ChallengesScreen(),
    ProfileScreen(),
  ];

  final List<String> _screenTitles = [
    'TrashTagger',
    'Map View',
    'Report Trash',
    'Challenges',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUnreadNotificationCount();
    _setupNotificationListener();
  }

  void _loadUnreadNotificationCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        final count = await NotificationService.getUnreadCount(
          authProvider.user!.uid,
        );
        if (mounted) {
          setState(() {
            _unreadNotificationCount = count;
          });
        }
      } catch (e) {
        debugPrint('Error loading unread count: $e');
      }
    }
  }

  void _setupNotificationListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      // Listen to real-time notification updates
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: authProvider.user!.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                _unreadNotificationCount = snapshot.docs.length;
              });
            }
          });
    }
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => NotificationsScreen()))
        .then((_) {
          // Refresh unread count when returning from notifications
          _loadUnreadNotificationCount();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: onTabTapped,
          backgroundColor: AppTheme.surfaceLight,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: AppTheme.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 2
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: _currentIndex == 2
                      ? Colors.white
                      : AppTheme.textSecondary,
                ),
              ),
              activeIcon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Challenges',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Updated AppBar widget for screens that need notification icon
class AppBarWithNotifications extends StatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double elevation;

  const AppBarWithNotifications({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.elevation = 0,
  }) : super(key: key);

  @override
  _AppBarWithNotificationsState createState() =>
      _AppBarWithNotificationsState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class _AppBarWithNotificationsState extends State<AppBarWithNotifications> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _setupListener();
  }

  void _loadUnreadCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        final count = await NotificationService.getUnreadCount(
          authProvider.user!.uid,
        );
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      } catch (e) {
        debugPrint('Error loading unread count: $e');
      }
    }
  }

  void _setupListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: authProvider.user!.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                _unreadCount = snapshot.docs.length;
              });
            }
          });
    }
  }

  void _navigateToNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => NotificationsScreen()))
        .then((_) {
          _loadUnreadCount();
        });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(widget.title),
      leading: widget.leading,
      elevation: widget.elevation,
      actions: [
        ...?widget.actions,
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined),
              onPressed: _navigateToNotifications,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
