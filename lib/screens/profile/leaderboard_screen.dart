// lib/screens/profile/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<UserModel> _globalLeaderboard = [];
  List<UserModel> _monthlyLeaderboard = [];
  List<UserModel> _weeklyLeaderboard = [];

  bool _isLoading = true;
  int? _currentUserGlobalRank;
  int? _currentUserMonthlyRank;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaderboards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboards() async {
    setState(() => _isLoading = true);

    try {
      // Load global leaderboard
      final globalSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalPoints', descending: true)
          .limit(100)
          .get();

      _globalLeaderboard = globalSnapshot.docs
          .map((doc) => UserModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();

      // Load monthly leaderboard
      final monthlySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('stats.monthlyPoints', descending: true)
          .where('stats.monthlyPoints', isGreaterThan: 0)
          .limit(100)
          .get();

      _monthlyLeaderboard = monthlySnapshot.docs
          .map((doc) => UserModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();

      // Find current user's rank
      final currentUserId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).user?.uid;
      if (currentUserId != null) {
        _currentUserGlobalRank =
            _globalLeaderboard.indexWhere((user) => user.id == currentUserId) +
            1;
        _currentUserMonthlyRank =
            _monthlyLeaderboard.indexWhere((user) => user.id == currentUserId) +
            1;

        if (_currentUserGlobalRank == 0) _currentUserGlobalRank = null;
        if (_currentUserMonthlyRank == 0) _currentUserMonthlyRank = null;
      }
    } catch (e) {
      print('Error loading leaderboards: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboards,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Time'),
            Tab(text: 'This Month'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading leaderboards...')
          : Column(
              children: [
                // Current User Rank
                _buildCurrentUserRank(),

                // Leaderboard Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeaderboardTab(_globalLeaderboard, 'totalPoints'),
                      _buildLeaderboardTab(
                        _monthlyLeaderboard,
                        'monthlyPoints',
                      ),
                      _buildComingSoonTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentUserRank() {
    final currentUserId = Provider.of<AuthProvider>(context).user?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Your Ranking',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRankInfo(
                    'Global',
                    _currentUserGlobalRank?.toString() ?? 'Unranked',
                    Icons.public,
                  ),
                  _buildRankInfo(
                    'Monthly',
                    _currentUserMonthlyRank?.toString() ?? 'Unranked',
                    Icons.calendar_month,
                  ),
                  _buildRankInfo('Weekly', 'Coming Soon', Icons.calendar_today),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankInfo(String label, String rank, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          rank,
          style: AppTheme.headlineMedium.copyWith(
            fontSize: 18,
            color: AppTheme.primaryGreen,
          ),
        ),
        Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _buildLeaderboardTab(List<UserModel> users, String pointsField) {
    if (users.isEmpty) {
      return const Center(child: Text('No users in this leaderboard yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboards,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final rank = index + 1;
          return _buildLeaderboardItem(user, rank, pointsField);
        },
      ),
    );
  }

  Widget _buildLeaderboardItem(UserModel user, int rank, String pointsField) {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.uid;
    final isCurrentUser = user.id == currentUserId;

    int points;
    switch (pointsField) {
      case 'monthlyPoints':
        points = user.stats.monthlyPoints;
        break;
      case 'weeklyPoints':
        points = user.stats.weeklyStreak * 10; // Placeholder calculation
        break;
      default:
        points = user.totalPoints;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isCurrentUser ? 4 : 1,
        color: isCurrentUser ? AppTheme.primaryGreen.withOpacity(0.1) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getRankColor(rank),
                  border: isCurrentUser
                      ? Border.all(color: AppTheme.primaryGreen, width: 2)
                      : null,
                ),
                child: Center(
                  child: rank <= 3
                      ? Icon(
                          rank == 1 ? Icons.emoji_events : Icons.military_tech,
                          color: Colors.white,
                          size: 20,
                        )
                      : Text(
                          rank.toString(),
                          style: AppTheme.labelMedium.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Profile Picture
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryGreen,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: AppTheme.labelMedium.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: isCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'YOU',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Level ${user.level}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (user.badges.isNotEmpty) ...[
                          Icon(
                            Icons.military_tech,
                            size: 12,
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${user.badges.length}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.warningOrange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Helpers.formatPoints(points),
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'points',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 80, color: AppTheme.textSecondary),
            const SizedBox(height: 24),
            Text(
              'Weekly Leaderboard',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon!',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Weekly competitions and streaks will be available in the next update.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
}
