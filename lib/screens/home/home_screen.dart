// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadCurrentUser(authProvider.user!.uid);
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
            user.stats.reportsSubmitted.toString(),
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

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),
            // TODO: Add actual recent activity items
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.lightGreen,
                child: Icon(Icons.eco, color: AppTheme.primaryGreen),
              ),
              title: Text('No recent activity'),
              subtitle: Text('Start by reporting some trash!'),
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
                  // Navigate to camera
                  Navigator.pushNamed(context, '/camera');
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
                  // Navigate to challenges
                  Navigator.pushNamed(context, '/challenges');
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

  double _calculateLevelProgress(int points, int level) {
    // Calculate points needed for current and next level
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
}
