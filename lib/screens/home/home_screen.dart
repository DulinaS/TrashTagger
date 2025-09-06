// lib/screens/home/home_screen.dart - Modern Vibrant Design (Completed)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../models/trash_report_model.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/page_transitions.dart';
import '../test/notification_test_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isLoadingReports = false;
  List<TrashReportModel> _userReports = [];
  List<TrashReportModel> _recentActivity = [];
  int _unreadNotificationCount = 0;

  // Animation controllers
  late AnimationController _refreshController;
  late AnimationController _statsController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: AnimationConstants.refreshDuration,
      vsync: this,
    );
    _statsController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadUnreadNotificationCount();
      _setupNotificationListener();

      // Start animations
      Future.delayed(AnimationConstants.shortDelay, () {
        if (mounted) _statsController.forward();
      });
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadCurrentUser(authProvider.user!.uid);

      await _loadUserReports(authProvider.user!.uid);
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
        .push(
          PageTransitions.slideFromRight(
            page: NotificationsScreen(),
            duration: AnimationConstants.mediumDuration,
          ),
        )
        .then((_) {
          _loadUnreadNotificationCount();
        });
  }

  void _navigateToTab(int tabIndex) {
    mainNavKey.currentState?.onTabTapped(tabIndex);
  }

  Future<void> _refreshData() async {
    _refreshController.forward().then((_) {
      _refreshController.reset();
    });

    _loadData();
    _loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            if (userProvider.isLoading) {
              return const ModernLoadingWidget(
                message: 'Loading your profile...',
              );
            }

            final user = userProvider.currentUser;
            if (user == null) {
              return ModernEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to Load Profile',
                message: 'Please try again or restart the app.',
                actionText: 'Retry',
                onAction: _refreshData,
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    SlideInAnimation(
                      delay: AnimationConstants.microDelay,
                      child: _buildWelcomeSection(user),
                    ),
                    const SizedBox(height: 24),

                    // Quick Stats
                    StaggeredListAnimation(
                      itemDelay: const Duration(milliseconds: 80),
                      children: [_buildQuickStats(user)],
                    ),
                    const SizedBox(height: 24),

                    // Notifications Preview
                    if (_unreadNotificationCount > 0) ...[
                      SlideInAnimation(
                        delay: AnimationConstants.mediumDelay,
                        child: _buildNotificationPreview(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // My Reports Section
                    SlideInAnimation(
                      delay: AnimationConstants.longDelay,
                      child: _buildMyReportsSection(),
                    ),
                    const SizedBox(height: 24),

                    // Recent Activity
                    SlideInAnimation(
                      delay: AnimationConstants.extraLongDelay,
                      child: _buildRecentActivity(),
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    ScaleInAnimation(
                      delay: const Duration(milliseconds: 600),
                      child: _buildQuickActions(),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryEmerald.withOpacity(0.1),
                AppTheme.accentPurple.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                'TrashTagger',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        // Notification button with modern badge
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.textPrimary,
                  ),
                  onPressed: _navigateToNotifications,
                ),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: PulseAnimation(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.errorGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        _unreadNotificationCount > 99
                            ? '99+'
                            : _unreadNotificationCount.toString(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Debug notification button
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: IconButton(
                icon: Icon(Icons.bug_report, color: AppTheme.warningAmber),
                onPressed: () async {
                  await NotificationService.sendTestNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          const Text('Test notification sent!'),
                        ],
                      ),
                      backgroundColor: AppTheme.primaryEmerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWelcomeSection(user) {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      enableGlassmorphism: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryEmerald.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: user.photoURL != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          user.photoURL!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: AppTheme.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 20),
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
                    const SizedBox(height: 4),
                    Text(
                      user.name,
                      style: AppTheme.headlineMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Level ${user.level} • ${Helpers.formatPoints(user.totalPoints)} pts',
                        style: AppTheme.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Level Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to Level ${user.level + 1}',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_getPointsToNextLevel(user.totalPoints, user.level)} pts to go',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _calculateLevelProgress(
                    user.totalPoints,
                    user.level,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(user) {
    final stats = [
      {
        'label': 'Reports',
        'value': _userReports.length.toString(),
        'icon': Icons.report_outlined,
        'color': AppTheme.infoBlue,
        'gradient': LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        ),
      },
      {
        'label': 'Cleanups',
        'value': user.stats.challengesCompleted.toString(),
        'icon': Icons.cleaning_services_outlined,
        'color': AppTheme.primaryEmerald,
        'gradient': AppTheme.successGradient,
      },
      {
        'label': 'Badges',
        'value': user.badges.length.toString(),
        'icon': Icons.military_tech_outlined,
        'color': AppTheme.accentAmber,
        'gradient': AppTheme.warningGradient,
      },
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < stats.length - 1 ? 12 : 0),
            child: ScaleInAnimation(
              delay: Duration(milliseconds: 200 + (index * 100)),
              child: _buildStatCard(
                stat['label'] as String,
                stat['value'] as String,
                stat['icon'] as IconData,
                stat['gradient'] as LinearGradient,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    LinearGradient gradient,
  ) {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: gradient.colors.first,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return ModernCard(
      onTap: _navigateToNotifications,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
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
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view updates about challenges, badges, and more',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyReportsSection() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Reports',
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (_userReports.isNotEmpty)
                TextButton(
                  onPressed: () => _navigateToTab(1), // Navigate to map/reports
                  child: Text(
                    'View All',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.primaryEmerald,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoadingReports)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ModernLoadingWidget(message: 'Loading reports...'),
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
    );
  }

  Widget _buildEmptyReports() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          ScaleInAnimation(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No reports yet',
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by reporting some trash in your area!',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ModernGradientButton(
            text: 'Report Trash',
            onPressed: () => _navigateToTab(2),
            icon: Icons.camera_alt_rounded,
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.getSeverityGradient(report.severity),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getTrashTypeIcon(report.trashType),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Helpers.getTrashTypeDisplayName(report.trashType),
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.address,
                  style: AppTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  Helpers.formatDateTime(report.timestamp),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          ModernStatusBadge(
            status: report.status,
            showPulse: report.status == 'pending',
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.successGreen, AppTheme.primaryEmerald],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.eco_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Community Activity',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_recentActivity.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent activity',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildActivityItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppTheme.successGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New ${report.trashType} report',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${Helpers.formatDateTime(report.timestamp)} • ${report.address}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppTheme.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': 'Report Trash',
        'subtitle': 'Take a photo and report',
        'icon': Icons.camera_alt_rounded,
        'gradient': AppTheme.primaryGradient,
        'onTap': () => _navigateToTab(2),
      },
      {
        'title': 'Find Cleanup',
        'subtitle': 'Help clean up nearby',
        'icon': Icons.search_rounded,
        'gradient': LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        ),
        'onTap': () => _navigateToTab(3),
      },
      {
        'title': 'View Map',
        'subtitle': 'See nearby reports',
        'icon': Icons.map_outlined,
        'gradient': AppTheme.warningGradient,
        'onTap': () => _navigateToTab(1),
      },
      {
        'title': 'My Profile',
        'subtitle': 'View achievements',
        'icon': Icons.person_outlined,
        'gradient': LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        ),
        'onTap': () => _navigateToTab(4),
      },
    ];

    if (kDebugMode) {
      actions.add({
        'title': 'Test Notifications',
        'subtitle': 'Debug notification system',
        'icon': Icons.bug_report,
        'gradient': AppTheme.errorGradient,
        'onTap': () {
          Navigator.push(
            context,
            PageTransitions.slideFromRight(page: NotificationTestScreen()),
          );
        },
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return ScaleInAnimation(
              delay: Duration(milliseconds: 100 + (index * 50)),
              child: _buildActionCard(
                action['title'] as String,
                action['subtitle'] as String,
                action['icon'] as IconData,
                action['gradient'] as LinearGradient,
                action['onTap'] as VoidCallback,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return ModernCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
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

  IconData _getTrashTypeIcon(String trashType) {
    switch (trashType) {
      case 'general':
        return Icons.delete_rounded;
      case 'recyclable':
        return Icons.recycling_rounded;
      case 'hazardous':
        return Icons.warning_rounded;
      case 'large':
        return Icons.chair_rounded;
      case 'organic':
        return Icons.eco_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}
