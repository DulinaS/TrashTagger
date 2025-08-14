// lib/screens/home/home_screen.dart - Updated with real data
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/test_maps.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../models/trash_report_model.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingReports = false;
  List<TrashReportModel> _userReports = [];
  List<TrashReportModel> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
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
              '_documentId': doc.id, // Use actual document ID
              ...doc.data(),
            }),
          )
          .toList();
    } catch (e) {
      print('Error loading user reports: $e');
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
          .map((doc) => TrashReportModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();

      setState(() {});
    } catch (e) {
      print('Error loading recent activity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('TrashTagger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
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
            return const Center(child: Text('Unable to load user data'));
          }

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
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

                  // My Reports Section
                  _buildMyReportsSection(),
                  const SizedBox(height: 24),

                  // Recent Activity
                  _buildRecentActivity(),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TestMapsScreen(),
                        ),
                      );
                    },
                    child: Text('🗺️ Test Maps'),
                  ),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back, ${user.name}!', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Level ${user.level} • ${Helpers.formatPoints(user.totalPoints)} points',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _calculateLevelProgress(user.totalPoints, user.level),
              backgroundColor: AppTheme.lightGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress to Level ${user.level + 1}',
              style: AppTheme.bodyMedium,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: AppTheme.headlineMedium.copyWith(color: color)),
            Text(label, style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildMyReportsSection() {
    return Card(
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
                      // TODO: Navigate to full reports list
                    },
                    child: Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoadingReports)
              const Center(child: CircularProgressIndicator())
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildReportItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lightGreen),
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
                fontSize: 12,
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Community Activity', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            if (_recentActivity.isEmpty)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.lightGreen,
                  child: Icon(Icons.eco, color: AppTheme.primaryGreen),
                ),
                title: Text('No recent activity'),
                subtitle: Text('Be the first to report trash today!'),
              )
            else
              Column(
                children: _recentActivity
                    .take(3)
                    .map(
                      (report) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.lightGreen,
                          child: Icon(
                            Icons.location_on,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        title: Text('New ${report.trashType} report'),
                        subtitle: Text(
                          '${Helpers.formatDateTime(report.timestamp)} • ${report.address}',
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: Navigate to report details
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTheme.headlineMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Report Trash',
                'Take a photo and report',
                Icons.camera_alt,
                AppTheme.primaryGreen,
                () {
                  // Navigate to camera (index 2 in bottom navigation)
                  DefaultTabController.of(context)?.animateTo(2);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Find Cleanup',
                'Help clean up nearby',
                Icons.search,
                AppTheme.infoBlue,
                () {
                  DefaultTabController.of(context)?.animateTo(3);
                },
              ),
            ),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTheme.bodyMedium,
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
