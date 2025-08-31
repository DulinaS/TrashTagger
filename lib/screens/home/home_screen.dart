// lib/screens/home/home_screen.dart - Complete version with notification integration
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../models/trash_report_model.dart';
import '../test/notification_test_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingReports = false;
  List<TrashReportModel> _userReports = [];
  List<TrashReportModel> _recentActivity = [];
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadUnreadNotificationCount();
      _setupNotificationListener();
    });
  }

  void _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      // Load user profile
      await Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadCurrentUser(authProvider.user!.uid);

      // Load user's reports
      await _loadUserReports(authProvider.user!.uid);

      // Load recent activity
      await _loadRecentActivity();
    }
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
        debugPrint('Error loading unread notification count: $e');
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

  Future<void> _loadUserReports(String userId) async {
    setState(() => _isLoadingReports = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('reporterId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      _userReports = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id,
              ...doc.data(),
            }),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading user reports: $e');
    }

    setState(() => _isLoadingReports = false);
  }

  Future<void> _loadRecentActivity() async {
    try {
      // Get recent verified reports (last 24 hours)
      final yesterday = DateTime.now().subtract(Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', isEqualTo: 'verified')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      _recentActivity = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id,
              ...doc.data(),
            }),
          )
          .toList();

      setState(() {});
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
    }
  }

  void _navigateToNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => NotificationsScreen()))
        .then((_) {
          // Refresh unread count when returning from notifications
          _loadUnreadNotificationCount();
        });
  }

  void _navigateToTab(int tabIndex) {
    // This assumes you have a way to change tabs in your MainNavigationScreen
    // You might need to implement this based on your navigation structure
    Navigator.of(context).pop(); // Close any current screen
    // Then navigate to the specific tab - implementation depends on your structure
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('TrashTagger'),
        elevation: 0,
        automaticallyImplyLeading:
            false, // Remove back button since this is main screen
        actions: [
          // Notification button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _navigateToNotifications,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : _unreadNotificationCount.toString(),
                      style: const TextStyle(
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
          // Test notification button (remove in production)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                await NotificationService.sendTestNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent!')),
                );
              },
            ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading) {
            return const LoadingWidget(message: 'Loading your profile...');
          }

          final user = userProvider.currentUser;
          if (user == null) {
            return const Center(
              child: Text('Unable to load user data. Please try again.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadData();
              _loadUnreadNotificationCount();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(user),
                  const SizedBox(height: 24),

                  // Quick Stats
                  _buildQuickStats(user),
                  const SizedBox(height: 24),

                  // Notifications Preview (if any unread)
                  if (_unreadNotificationCount > 0) ...[
                    _buildNotificationPreview(),
                    const SizedBox(height: 24),
                  ],

                  // My Reports Section
                  _buildMyReportsSection(),
                  const SizedBox(height: 24),

                  // Recent Activity
                  _buildRecentActivity(),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection(user) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryGreen,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        user.name,
                        style: AppTheme.headlineMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Level ${user.level} • ${Helpers.formatPoints(user.totalPoints)} pts',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Level Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress to Level ${user.level + 1}',
                      style: AppTheme.labelMedium,
                    ),
                    Text(
                      '${_getPointsToNextLevel(user.totalPoints, user.level)} pts to go',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _calculateLevelProgress(user.totalPoints, user.level),
                  backgroundColor: AppTheme.lightGreen.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGreen,
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(user) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Reports',
            _userReports.length.toString(),
            Icons.report_outlined,
            AppTheme.infoBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Cleanups',
            user.stats.challengesCompleted.toString(),
            Icons.cleaning_services_outlined,
            AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Badges',
            user.badges.length.toString(),
            Icons.military_tech_outlined,
            AppTheme.warningOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTheme.headlineMedium.copyWith(
                color: color,
                fontSize: 20,
              ),
            ),
            Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _navigateToNotifications,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have $_unreadNotificationCount new notification${_unreadNotificationCount == 1 ? '' : 's'}',
                      style: AppTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view updates about challenges, badges, and more',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyReportsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Reports', style: AppTheme.headlineMedium),
                if (_userReports.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // Navigate to full reports list
                      // Implementation depends on your navigation structure
                    },
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoadingReports)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_userReports.isEmpty)
              _buildEmptyReports()
            else
              Column(
                children: _userReports
                    .take(3)
                    .map((report) => _buildReportItem(report))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReports() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No reports yet',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by reporting some trash in your area!',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to camera screen
              _navigateToTab(2); // Assuming camera is at index 2
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Report Trash'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(report.status),
            ),
            child: Icon(
              _getStatusIcon(report.status),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Report Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Helpers.getTrashTypeDisplayName(report.trashType),
                  style: AppTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  report.address,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  Helpers.formatDateTime(report.timestamp),
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(report.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusDisplayName(report.status),
              style: AppTheme.bodyMedium.copyWith(
                fontSize: 11,
                color: _getStatusColor(report.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Community Activity', style: AppTheme.headlineMedium),
                const SizedBox(width: 8),
                Icon(Icons.eco, color: AppTheme.primaryGreen, size: 20),
              ],
            ),
            const SizedBox(height: 16),

            if (_recentActivity.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.lightGreen.withOpacity(0.3),
                      child: Icon(Icons.eco, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No recent activity',
                            style: AppTheme.labelMedium,
                          ),
                          Text(
                            'Be the first to report trash today!',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _recentActivity
                    .take(3)
                    .map((report) => _buildActivityItem(report))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.lightGreen.withOpacity(0.3),
            child: Icon(
              Icons.location_on,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New ${report.trashType} report',
                  style: AppTheme.labelMedium,
                ),
                Text(
                  '${Helpers.formatDateTime(report.timestamp)} • ${report.address}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTheme.headlineMedium),
        const SizedBox(height: 16),

        // Primary actions
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Report Trash',
                'Take a photo and report',
                Icons.camera_alt,
                AppTheme.primaryGreen,
                () => _navigateToTab(2), // Navigate to camera tab
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Find Cleanup',
                'Help clean up nearby',
                Icons.search,
                AppTheme.infoBlue,
                () => _navigateToTab(3), // Navigate to challenges tab
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Secondary actions
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'View Map',
                'See nearby reports',
                Icons.map_outlined,
                AppTheme.warningOrange,
                () => _navigateToTab(1), // Navigate to map tab
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'My Profile',
                'View achievements',
                Icons.person_outlined,
                AppTheme.textSecondary,
                () => _navigateToTab(4), // Navigate to profile tab
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Test Notifications',
                'Debug notification system',
                Icons.bug_report,
                AppTheme.warningOrange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationTestScreen(),
                    ),
                  );
                },
              ),
            ),
            Expanded(child: Container()), // Empty space
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  double _calculateLevelProgress(int points, int level) {
    int currentLevelPoints = _getPointsForLevel(level);
    int nextLevelPoints = _getPointsForLevel(level + 1);

    if (points >= nextLevelPoints) return 1.0;

    int progressPoints = points - currentLevelPoints;
    int totalPointsNeeded = nextLevelPoints - currentLevelPoints;

    return progressPoints / totalPointsNeeded;
  }

  int _getPointsForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 50;
    if (level == 3) return 150;
    if (level == 4) return 300;
    if (level == 5) return 500;
    return 500 + ((level - 5) * 200);
  }

  int _getPointsToNextLevel(int currentPoints, int level) {
    int nextLevelPoints = _getPointsForLevel(level + 1);
    return nextLevelPoints - currentPoints;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningOrange;
      case 'verified':
        return AppTheme.primaryGreen;
      case 'cleaning':
        return AppTheme.infoBlue;
      case 'completed':
        return AppTheme.primaryGreen;
      case 'rejected':
        return AppTheme.dangerRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'verified':
        return Icons.check_circle;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'completed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'cleaning':
        return 'Cleaning';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }
}
