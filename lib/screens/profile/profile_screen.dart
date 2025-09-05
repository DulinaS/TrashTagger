// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/screens/profile/badges_screen.dart';
import 'package:trash_tagger/screens/profile/leaderboard_screen.dart';
import 'package:trash_tagger/screens/profile/settings_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../models/user_model.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<UserModel> _leaderboard = [];
  bool _isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalPoints', descending: true)
          .limit(10)
          .get();

      _leaderboard = snapshot.docs
          .map((doc) => UserModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error loading leaderboard: $e');
    }

    setState(() => _isLoadingLeaderboard = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _routeToSettingsScreen(),
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
            return const Center(child: Text('Unable to load profile'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                _buildProfileHeader(user),
                const SizedBox(height: 24),

                // Stats Overview
                _buildStatsOverview(user),
                const SizedBox(height: 24),

                // Achievements Section
                _buildAchievementsSection(user),
                const SizedBox(height: 24),

                // Leaderboard Section
                _buildLeaderboardSection(),
                const SizedBox(height: 24),

                // Sign Out Button
                _buildSignOutSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryGreen,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: AppTheme.headlineLarge.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Name and Level
            Text(
              user.name,
              style: AppTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Level ${user.level} • ${Helpers.formatPoints(user.totalPoints)} points',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Level Progress
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level ${user.level}', style: AppTheme.bodyMedium),
                    Text('Level ${user.level + 1}', style: AppTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _calculateLevelProgress(user.totalPoints, user.level),
                  backgroundColor: AppTheme.lightGreen,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getPointsToNextLevel(user.totalPoints, user.level)} points to next level',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Impact', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Reports',
                    user.stats.reportsSubmitted.toString(),
                    Icons.report_outlined,
                    AppTheme.infoBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Cleanups',
                    user.stats.challengesCompleted.toString(),
                    Icons.cleaning_services_outlined,
                    AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Monthly Points',
                    user.stats.monthlyPoints.toString(),
                    Icons.trending_up,
                    AppTheme.warningOrange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Weekly Streak',
                    user.stats.weeklyStreak.toString(),
                    Icons.local_fire_department,
                    AppTheme.dangerRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTheme.headlineMedium.copyWith(color: color)),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Achievements', style: AppTheme.headlineMedium),
                TextButton(
                  onPressed: () => _routeToBadgesScreen(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (user.badges.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.military_tech_outlined,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No badges yet',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete challenges to earn your first badge!',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: user.badges.length > 8 ? 8 : user.badges.length,
                itemBuilder: (context, index) {
                  final badgeId = user.badges[index];
                  return _buildBadgeItem(badgeId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(String badgeId) {
    // Map badge IDs to display info
    final badgeInfo = _getBadgeInfo(badgeId);

    return Container(
      decoration: BoxDecoration(
        color: badgeInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeInfo['color'].withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(badgeInfo['icon'], size: 28, color: badgeInfo['color']),
          const SizedBox(height: 4),
          Text(
            badgeInfo['name'],
            style: AppTheme.bodyMedium.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Leaderboard', style: AppTheme.headlineMedium),
                TextButton(
                  onPressed: () => _routeToLeaderboardScreen(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoadingLeaderboard)
              const Center(child: CircularProgressIndicator())
            else if (_leaderboard.isEmpty)
              const Center(child: Text('No leaderboard data available'))
            else
              Column(
                children: _leaderboard.take(5).map((user) {
                  final index = _leaderboard.indexOf(user);
                  return _buildLeaderboardItem(user, index + 1);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(UserModel user, int rank) {
    final isCurrentUser =
        Provider.of<AuthProvider>(context, listen: false).user?.uid == user.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppTheme.primaryGreen.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryGreen.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getRankColor(rank),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Profile Picture
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryGreen,
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: AppTheme.labelMedium.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Level ${user.level}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Helpers.formatPoints(user.totalPoints),
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'points',
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          if (isCurrentUser)
            Icon(Icons.person, color: AppTheme.primaryGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildSignOutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.settings, color: AppTheme.textSecondary),
              title: const Text('Settings'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _routeToSettingsScreen(),
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: AppTheme.textSecondary),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HelpSupportScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: AppTheme.dangerRed),
              title: Text(
                'Sign Out',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.dangerRed),
              ),
              onTap: _showSignOutDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.dangerRed),
            ),
          ),
        ],
      ),
    );
  }

  void _routeToBadgesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BadgesScreen()),
    );
  }

  void _routeToLeaderboardScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LeaderboardScreen()),
    );
  }

  void _routeToSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppTheme.primaryGreen;
    }
  }

  Map<String, dynamic> _getBadgeInfo(String badgeId) {
    final badgeMap = {
      'first_report': {
        'name': 'First Step',
        'icon': Icons.flag,
        'color': AppTheme.primaryGreen,
      },
      'first_cleanup': {
        'name': 'Cleanup Hero',
        'icon': Icons.cleaning_services,
        'color': AppTheme.infoBlue,
      },
      'reporter_bronze': {
        'name': 'Bronze Reporter',
        'icon': Icons.report,
        'color': const Color(0xFFCD7F32),
      },
      'cleaner_bronze': {
        'name': 'Bronze Cleaner',
        'icon': Icons.eco,
        'color': const Color(0xFFCD7F32),
      },
      'century_club': {
        'name': 'Century Club',
        'icon': Icons.star,
        'color': AppTheme.warningOrange,
      },
      'high_achiever': {
        'name': 'High Achiever',
        'icon': Icons.emoji_events,
        'color': const Color(0xFFFFD700),
      },
      'hazard_handler': {
        'name': 'Hazard Handler',
        'icon': Icons.warning,
        'color': AppTheme.dangerRed,
      },
      'recycling_champion': {
        'name': 'Recycling Champion',
        'icon': Icons.recycling,
        'color': AppTheme.primaryGreen,
      },
      'weekly_warrior': {
        'name': 'Weekly Warrior',
        'icon': Icons.local_fire_department,
        'color': AppTheme.dangerRed,
      },
      'top_ten': {
        'name': 'Top 10',
        'icon': Icons.military_tech,
        'color': const Color(0xFFFFD700),
      },
    };

    return badgeMap[badgeId] ??
        {'name': 'Badge', 'icon': Icons.help, 'color': AppTheme.textSecondary};
  }
}
