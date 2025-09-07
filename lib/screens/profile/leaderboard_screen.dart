// lib/screens/profile/leaderboard_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<UserModel> _globalLeaderboard = [];
  List<UserModel> _monthlyLeaderboard = [];
  List<UserModel> _weeklyLeaderboard = [];

  bool _isLoading = true;
  int? _currentUserGlobalRank;
  int? _currentUserMonthlyRank;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _rankController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeAnimations();
    _loadLeaderboards();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _rankController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slideController.dispose();
    _rankController.dispose();
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

      // Start animations after data loads
      Future.delayed(AnimationConstants.shortDelay, () {
        if (mounted) {
          _slideController.forward();
          _rankController.forward();
        }
      });
    } catch (e) {
      print('Error loading leaderboards: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: _isLoading
            ? const ModernLoadingWidget(message: 'Loading leaderboards...')
            : Column(
                children: [
                  const SizedBox(height: 10),
                  // Animated Tab Bar
                  SlideInAnimation(
                    delay: AnimationConstants.mediumDelay,
                    child: _buildAnimatedTabBar(),
                  ),

                  // Current User Rank
                  SlideInAnimation(
                    delay: AnimationConstants.microDelay,
                    child: _buildCurrentUserRank(),
                  ),

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
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentAmber.withOpacity(0.1),
                AppTheme.warningAmber.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.warningGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.leaderboard_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Leaderboard',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
              onPressed: _loadLeaderboards,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warningAmber.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.accentAmber,
        unselectedLabelColor: AppTheme.warningAmber,
        labelStyle: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTheme.labelMedium,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppTheme.primaryGradient.scale(0.1),
        ),
        indicatorPadding: const EdgeInsets.all(2),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Container(
            height: 48, // Set fixed height for proper coverage
            child: Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'All Time',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48, // Set fixed height for proper coverage
            child: Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'This Month',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48, // Set fixed height for proper coverage
            child: Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Weekly',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
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
      margin: const EdgeInsets.all(20),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        backgroundColor: AppTheme.accentAmber.withOpacity(0.05),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.warningGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Your Ranking',
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // FIXED: Use IntrinsicHeight to ensure equal height and better spacing
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: ScaleInAnimation(
                      delay: AnimationConstants.shortDelay,
                      child: _buildRankInfo(
                        'Global',
                        _currentUserGlobalRank?.toString() ?? 'N/A',
                        Icons.public_rounded,
                        AppTheme.primaryGradient,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced spacing
                  Expanded(
                    child: ScaleInAnimation(
                      delay: AnimationConstants.mediumDelay,
                      child: _buildRankInfo(
                        'Monthly',
                        _currentUserMonthlyRank?.toString() ?? 'N/A',
                        Icons.calendar_month_rounded,
                        LinearGradient(
                          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced spacing
                  Expanded(
                    child: ScaleInAnimation(
                      delay: AnimationConstants.longDelay,
                      child: _buildRankInfo(
                        'Weekly',
                        'Soon', // Shortened text
                        Icons.calendar_today_rounded,
                        LinearGradient(
                          colors: [
                            AppTheme.textSecondary,
                            AppTheme.borderMedium,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankInfo(
    String label,
    String rank,
    IconData icon,
    LinearGradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding for better fit
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Prevent unnecessary expansion
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ), // Slightly smaller icon
          ),
          const SizedBox(height: 8),
          // FIXED: Constrain rank text to prevent overflow
          SizedBox(
            height: 22, // Fixed height to prevent layout shifts
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                rank,
                style: AppTheme.titleMedium.copyWith(
                  // Changed from titleLarge to titleMedium
                  color: gradient.colors.first,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
          // FIXED: Constrain label text
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11, // Slightly smaller font
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(List<UserModel> users, String pointsField) {
    if (users.isEmpty) {
      return ModernEmptyState(
        icon: Icons.leaderboard_rounded,
        title: 'No users in this leaderboard yet',
        message: 'Be the first to start earning points!',
        actionText: 'Start Earning',
        onAction: () => Navigator.pop(context),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboards,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final rank = index + 1;
          return SlideInAnimation(
            delay: Duration(milliseconds: 50 + (index * 25)),
            child: _buildLeaderboardItem(user, rank, pointsField),
          );
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
        points = user.stats.weeklyStreak * 10;
        break;
      default:
        points = user.totalPoints;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        padding: const EdgeInsets.all(20),
        backgroundColor: isCurrentUser
            ? AppTheme.primaryEmerald.withOpacity(0.05)
            : null,
        border: isCurrentUser
            ? Border.all(
                color: AppTheme.primaryEmerald.withOpacity(0.3),
                width: 2,
              )
            : null,
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _getRankGradient(rank),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getRankColor(rank).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: rank <= 3
                    ? Icon(
                        rank == 1
                            ? Icons.emoji_events_rounded
                            : Icons.military_tech_rounded,
                        color: Colors.white,
                        size: 24,
                      )
                    : Text(
                        rank.toString(),
                        style: AppTheme.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // Profile Picture
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryEmerald.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.transparent,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: AppTheme.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
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
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: isCurrentUser
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'YOU',
                            style: AppTheme.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Level ${user.level}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.infoBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (user.badges.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.military_tech_rounded,
                                size: 12,
                                color: AppTheme.accentAmber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${user.badges.length}',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.accentAmber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
                  style: AppTheme.headlineMedium.copyWith(
                    color: _getRankColor(rank),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'points',
                  style: AppTheme.bodySmall.copyWith(
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

  Widget _buildComingSoonTab() {
    return ModernEmptyState(
      icon: Icons.schedule_rounded,
      title: 'Weekly Leaderboard',
      message:
          'Weekly competitions and streaks will be available in the next update.',
      actionText: 'Coming Soon!',
      gradient: LinearGradient(
        colors: [AppTheme.textSecondary, AppTheme.borderMedium],
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
        return AppTheme.primaryEmerald;
    }
  }

  LinearGradient _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return LinearGradient(
          colors: [const Color(0xFFFFD700), const Color(0xFFFFA500)],
        );
      case 2:
        return LinearGradient(
          colors: [const Color(0xFFC0C0C0), const Color(0xFF808080)],
        );
      case 3:
        return LinearGradient(
          colors: [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
        );
      default:
        return AppTheme.primaryGradient;
    }
  }
}
