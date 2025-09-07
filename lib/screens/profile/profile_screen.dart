// lib/screens/profile/profile_screen.dart - Modern Vibrant Design
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
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  List<UserModel> _leaderboard = [];
  bool _isLoadingLeaderboard = false;

  late AnimationController _refreshController;
  late AnimationController _avatarController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _avatarController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _avatarController.repeat(reverse: true);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _avatarController.dispose();
    super.dispose();
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

  Future<void> _refreshProfile() async {
    _refreshController.forward().then((_) {
      _refreshController.reset();
    });
    await _loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading) {
            return const LoadingWidget(message: 'Loading your profile...');
          }

          final user = userProvider.currentUser;
          if (user == null) {
            return const Center(child: Text('Unable to load profile'));
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernAppBar(user),
              SliverToBoxAdapter(
                child: RefreshIndicator(
                  onRefresh: _refreshProfile,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Profile Stats Overview
                        SlideInAnimation(
                          delay: AnimationConstants.shortDelay,
                          child: _buildStatsOverview(user),
                        ),
                        const SizedBox(height: 24),

                        // Level Progress Card
                        SlideInAnimation(
                          delay: AnimationConstants.mediumDelay,
                          child: _buildLevelProgressCard(user),
                        ),
                        const SizedBox(height: 24),

                        // Quick Actions Grid
                        SlideInAnimation(
                          delay: AnimationConstants.longDelay,
                          child: _buildQuickActionsGrid(),
                        ),
                        const SizedBox(height: 24),

                        // Achievements Section
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 600),
                          child: _buildAchievementsSection(user),
                        ),
                        const SizedBox(height: 24),

                        // Leaderboard Section
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 700),
                          child: _buildLeaderboardSection(),
                        ),
                        const SizedBox(height: 24),

                        // Account Actions
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 800),
                          child: _buildAccountSection(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 200, // Reduced since no title needed
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                30,
                20,
                20,
              ), // Adjusted padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // FIXED: Use min size
                children: [
                  // Profile Avatar with Animation
                  AnimatedBuilder(
                    animation: _avatarController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_avatarController.value * 0.05),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: user.photoURL != null
                                ? Image.network(
                                    user.photoURL!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildDefaultAvatar(user.name),
                                  )
                                : _buildDefaultAvatar(user.name),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10), // Reduced spacing
                  // User Name
                  Text(
                    user.name,
                    style: AppTheme.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6), // Reduced spacing
                  // Level and Points Badge
                  Container(
                    constraints: BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 27,
                      vertical: 2, // Reduced padding
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(
                        18,
                      ), // Slightly reduced
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 16,
                        ), // Smaller icon
                        const SizedBox(width: 4), // Reduced spacing
                        Flexible(
                          child: Text(
                            'Level ${user.level} • ${Helpers.formatPoints(user.totalPoints)} pts',
                            style: AppTheme.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12, // Smaller font
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // REMOVED: title parameter since you don't want the 'Profile' title
        collapseMode: CollapseMode.parallax, // Changed since no title to pin
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => _routeToSettingsScreen(),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: AppTheme.displayMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Reports',
            user.stats.reportsSubmitted.toString(),
            Icons.report_rounded,
            AppTheme.primaryTeal,
            LinearGradient(colors: [AppTheme.primaryTeal, AppTheme.infoBlue]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Cleanups',
            user.stats.challengesCompleted.toString(),
            Icons.cleaning_services_rounded,
            AppTheme.primaryEmerald,
            AppTheme.successGradient,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Badges',
            user.badges.length.toString(),
            Icons.military_tech_rounded,
            AppTheme.accentAmber,
            AppTheme.warningGradient,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Streak',
            user.stats.weeklyStreak.toString(),
            Icons.local_fire_department_rounded,
            AppTheme.accentCoral,
            LinearGradient(colors: [AppTheme.accentCoral, AppTheme.errorRed]),
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
    LinearGradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgressCard(UserModel user) {
    final progress = _calculateLevelProgress(user.totalPoints, user.level);
    final pointsToNext = _getPointsToNextLevel(user.totalPoints, user.level);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentPurple.withOpacity(0.1),
            AppTheme.primaryTeal.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentPurple, AppTheme.primaryTeal],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
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
                      'Level Progress',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$pointsToNext points to Level ${user.level + 1}',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.accentPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.primaryTeal],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level ${user.level}', style: AppTheme.bodySmall),
              Text('Level ${user.level + 1}', style: AppTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0, // Decreased from 1.3 to give more height
          children: [
            _buildActionCard(
              'View Badges',
              'See achievements',
              Icons.military_tech_rounded,
              AppTheme.warningGradient,
              () => _routeToBadgesScreen(),
            ),
            _buildActionCard(
              'Leaderboard',
              'Compare ranking',
              Icons.leaderboard_rounded,
              LinearGradient(
                colors: [AppTheme.accentAmber, AppTheme.warningAmber],
              ),
              () => _routeToLeaderboardScreen(),
            ),
            _buildActionCard(
              'Settings',
              'Manage account',
              Icons.settings_rounded,
              LinearGradient(
                colors: [AppTheme.textSecondary, AppTheme.textTertiary],
              ),
              () => _routeToSettingsScreen(),
            ),
            _buildActionCard(
              'Help & Support',
              'Get assistance',
              Icons.help_rounded,
              LinearGradient(colors: [AppTheme.infoBlue, AppTheme.primaryTeal]),
              () => _routeToHelpScreen(),
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
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16), // Reduced from 20
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // FIXED: Use min size
              children: [
                Container(
                  width: 40, // Reduced from 48
                  height: 40, // Reduced from 48
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12), // Reduced from 14
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 6, // Reduced from 8
                        offset: const Offset(0, 3), // Reduced from 4
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ), // Reduced from 24
                ),
                const SizedBox(height: 8), // Reduced from 12
                Flexible(
                  // FIXED: Use Flexible for title
                  child: Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14, // Reduced font size
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2), // Reduced from 4
                Flexible(
                  // FIXED: Use Flexible for subtitle
                  child: Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: 11, // Reduced font size
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
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
                      gradient: AppTheme.warningGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Achievements',
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _routeToBadgesScreen(),
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

          if (user.badges.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.military_tech_outlined,
                      size: 40,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No badges yet',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
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
                childAspectRatio: 0.9,
              ),
              itemCount: user.badges.length > 8 ? 8 : user.badges.length,
              itemBuilder: (context, index) {
                final badgeId = user.badges[index];
                return _buildBadgeItem(badgeId);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(String badgeId) {
    final badgeInfo = _getBadgeInfo(badgeId);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeInfo['color'].withOpacity(0.1),
            badgeInfo['color'].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeInfo['color'].withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // Reduced padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // FIXED: Use min size
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28, // Reduced from 32
              height: 28, // Reduced from 32
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    badgeInfo['color'],
                    badgeInfo['color'].withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8), // Reduced from 10
              ),
              child: Icon(
                badgeInfo['icon'],
                size: 16,
                color: Colors.white,
              ), // Reduced size
            ),
            const SizedBox(height: 6), // Reduced spacing
            Flexible(
              // FIXED: Use Flexible instead of fixed spacing
              child: Text(
                badgeInfo['name'],
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11, // Slightly smaller font
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
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
                      gradient: LinearGradient(
                        colors: [AppTheme.accentAmber, AppTheme.warningAmber],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.leaderboard_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Leaderboard',
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _routeToLeaderboardScreen(),
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
    );
  }

  Widget _buildLeaderboardItem(UserModel user, int rank) {
    final isCurrentUser =
        Provider.of<AuthProvider>(context, listen: false).user?.uid == user.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryEmerald.withOpacity(0.1)
            : AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryEmerald.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: _getRankGradient(rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(
                      rank == 1
                          ? Icons.emoji_events_rounded
                          : Icons.military_tech_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      rank.toString(),
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Profile Picture
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryEmerald,
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

          // Name and Level - FIXED OVERFLOW
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Level ${user.level}',
                  style: AppTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Points - FIXED OVERFLOW
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Helpers.formatPoints(user.totalPoints),
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.primaryEmerald,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'points',
                style: AppTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.person_rounded,
              color: AppTheme.primaryEmerald,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          _buildAccountItem(
            'Settings',
            'Manage your preferences',
            Icons.settings_rounded,
            AppTheme.textSecondary,
            () => _routeToSettingsScreen(),
          ),
          _buildAccountItem(
            'Help & Support',
            'Get help and contact us',
            Icons.help_rounded,
            AppTheme.infoBlue,
            () => _routeToHelpScreen(),
          ),
          _buildAccountItem(
            'Sign Out',
            'Sign out of your account',
            Icons.logout_rounded,
            AppTheme.errorRed,
            _showSignOutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: title == 'Sign Out'
                              ? color
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(subtitle, style: AppTheme.bodySmall),
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
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.errorGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Provider.of<AuthProvider>(context, listen: false).signOut();
              },
              child: Text(
                'Sign Out',
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  void _routeToHelpScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HelpSupportScreen()),
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

  LinearGradient _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);
      case 2:
        return LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFF999999)]);
      case 3:
        return LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)]);
      default:
        return AppTheme.primaryGradient;
    }
  }

  Map<String, dynamic> _getBadgeInfo(String badgeId) {
    final badgeMap = {
      'first_report': {
        'name': 'First Step',
        'icon': Icons.flag_rounded,
        'color': AppTheme.primaryEmerald,
      },
      'first_cleanup': {
        'name': 'Cleanup Hero',
        'icon': Icons.cleaning_services_rounded,
        'color': AppTheme.infoBlue,
      },
      'reporter_bronze': {
        'name': 'Bronze Reporter',
        'icon': Icons.report_rounded,
        'color': Color(0xFFCD7F32),
      },
      'cleaner_bronze': {
        'name': 'Bronze Cleaner',
        'icon': Icons.eco_rounded,
        'color': Color(0xFFCD7F32),
      },
      'century_club': {
        'name': 'Century Club',
        'icon': Icons.star_rounded,
        'color': AppTheme.accentAmber,
      },
      'high_achiever': {
        'name': 'High Achiever',
        'icon': Icons.emoji_events_rounded,
        'color': Color(0xFFFFD700),
      },
      'hazard_handler': {
        'name': 'Hazard Handler',
        'icon': Icons.warning_rounded,
        'color': AppTheme.errorRed,
      },
      'recycling_champion': {
        'name': 'Recycling Champion',
        'icon': Icons.recycling_rounded,
        'color': AppTheme.primaryEmerald,
      },
      'weekly_warrior': {
        'name': 'Weekly Warrior',
        'icon': Icons.local_fire_department_rounded,
        'color': AppTheme.accentCoral,
      },
      'top_ten': {
        'name': 'Top 10',
        'icon': Icons.military_tech_rounded,
        'color': Color(0xFFFFD700),
      },
    };

    return badgeMap[badgeId] ??
        {
          'name': 'Badge',
          'icon': Icons.help_rounded,
          'color': AppTheme.textTertiary,
        };
  }
}
