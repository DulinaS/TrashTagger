// lib/screens/profile/badges_screen.dart - Fixed Overflow Issues
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/user_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class BadgesScreen extends StatefulWidget {
  @override
  _BadgesScreenState createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allBadges = [];
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _gridController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBadges();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );
    _gridController = AnimationController(
      duration: AnimationConstants.extraSlowDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('badges')
          .orderBy('pointsAwarded', descending: true)
          .get();

      _allBadges = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      // Start animations after data loads
      Future.delayed(AnimationConstants.shortDelay, () {
        if (mounted) {
          _progressController.forward();
          _gridController.forward();
        }
      });
    } catch (e) {
      print('Error loading badges: $e');
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
            ? const ModernLoadingWidget(message: 'Loading badges...')
            : Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final user = userProvider.currentUser;
                  if (user == null) {
                    return ModernEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to load user data',
                      message: 'Please try again or restart the app.',
                      actionText: 'Retry',
                      onAction: () => _loadBadges(),
                    );
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Progress Summary
                        SlideInAnimation(
                          delay: AnimationConstants.microDelay,
                          child: _buildProgressSummary(user.badges),
                        ),
                        const SizedBox(height: 32),

                        // Badge Categories
                        SlideInAnimation(
                          delay: AnimationConstants.mediumDelay,
                          child: _buildBadgeCategories(user.badges),
                        ),
                      ],
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
        title: LayoutBuilder(
          builder: (context, constraints) {
            // FIXED: Use LayoutBuilder and Flexible to prevent overflow
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.warningGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Achievements',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            );
          },
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
      ),
    );
  }

  Widget _buildProgressSummary(List<String> userBadges) {
    final earnedCount = userBadges.length;
    final totalCount = _allBadges.length;
    final progress = totalCount > 0 ? earnedCount / totalCount : 0.0;

    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
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
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Achievement Progress',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Circular Progress with Animation
          ScaleInAnimation(
            delay: AnimationConstants.shortDelay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: progress * _progressController.value,
                        strokeWidth: 12,
                        backgroundColor: AppTheme.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentAmber,
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$earnedCount',
                      style: AppTheme.displaySmall.copyWith(
                        color: AppTheme.accentAmber,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'of $totalCount',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Progress Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Completion Rate',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentAmber,
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
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress * _progressController.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.warningGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCategories(List<String> userBadges) {
    final categories = {
      'Milestone': _allBadges.where((b) => b['type'] == 'milestone').toList(),
      'Streak': _allBadges.where((b) => b['type'] == 'streak').toList(),
      'Special': _allBadges.where((b) => b['type'] == 'special').toList(),
      'Rank': _allBadges.where((b) => b['type'] == 'rank').toList(),
    };

    return Column(
      children: categories.entries.map((entry) {
        return _buildBadgeCategory(entry.key, entry.value, userBadges);
      }).toList(),
    );
  }

  Widget _buildBadgeCategory(
    String category,
    List<Map<String, dynamic>> badges,
    List<String> userBadges,
  ) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: _getCategoryGradient(category),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$category Badges',
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${userBadges.where((id) => badges.any((b) => b['id'] == id)).length}/${badges.length}',
                    style: AppTheme.labelMedium.copyWith(
                      color: _getCategoryColor(category),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StaggeredListAnimation(
              itemDelay: const Duration(milliseconds: 50),
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    final isEarned = userBadges.contains(badge['id']);
                    return _buildBadgeCard(badge, isEarned, index);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, bool isEarned, int index) {
    final rarity = badge['rarity'] ?? 'common';
    final rarityColor = _getRarityColor(rarity);

    return ScaleInAnimation(
      delay: Duration(milliseconds: 100 + (index * 50)),
      child: ModernCard(
        padding: const EdgeInsets.all(12),
        backgroundColor: isEarned
            ? rarityColor.withOpacity(0.05)
            : AppTheme.backgroundSecondary,
        border: isEarned
            ? Border.all(color: rarityColor.withOpacity(0.3), width: 2)
            : null,
        child: Stack(
          children: [
            // Main content with optimized spacing
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: isEarned
                        ? LinearGradient(
                            colors: [rarityColor, rarityColor.withOpacity(0.8)],
                          )
                        : null,
                    color: isEarned
                        ? null
                        : AppTheme.textSecondary.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: isEarned
                        ? [
                            BoxShadow(
                              color: rarityColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _getBadgeIcon(badge['id']),
                    size: 22,
                    color: isEarned ? Colors.white : AppTheme.textSecondary,
                  ),
                ),

                // Badge Name - Optimized spacing
                Container(
                  height: 32, // Reduced height for better fit
                  alignment: Alignment.center,
                  child: Text(
                    badge['name'] ?? 'Unknown',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isEarned
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight: isEarned ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Points and Rarity - Compact layout
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Points Reward
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: isEarned ? AppTheme.warningGradient : null,
                        color: isEarned
                            ? null
                            : AppTheme.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${badge['pointsAwarded'] ?? 0} pts',
                        style: AppTheme.labelMedium.copyWith(
                          color: isEarned
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Rarity
                    Text(
                      rarity.toUpperCase(),
                      style: AppTheme.bodySmall.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Lock overlay for unearned badges
            if (!isEarned)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),

            // Earned badge glow effect
            if (isEarned)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getCategoryGradient(String category) {
    switch (category) {
      case 'Milestone':
        return AppTheme.primaryGradient;
      case 'Streak':
        return AppTheme.errorGradient;
      case 'Special':
        return LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        );
      case 'Rank':
        return AppTheme.warningGradient;
      default:
        return AppTheme.primaryGradient;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Milestone':
        return AppTheme.primaryEmerald;
      case 'Streak':
        return AppTheme.errorRed;
      case 'Special':
        return AppTheme.accentPurple;
      case 'Rank':
        return AppTheme.accentAmber;
      default:
        return AppTheme.primaryEmerald;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Milestone':
        return Icons.flag_rounded;
      case 'Streak':
        return Icons.local_fire_department_rounded;
      case 'Special':
        return Icons.star_rounded;
      case 'Rank':
        return Icons.emoji_events_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'common':
        return AppTheme.textSecondary;
      case 'uncommon':
        return AppTheme.primaryEmerald;
      case 'rare':
        return AppTheme.infoBlue;
      case 'legendary':
        return AppTheme.accentAmber;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getBadgeIcon(String badgeId) {
    final iconMap = {
      'first_report': Icons.flag_rounded,
      'first_cleanup': Icons.cleaning_services_rounded,
      'reporter_bronze': Icons.report_rounded,
      'reporter_silver': Icons.report_rounded,
      'reporter_gold': Icons.report_rounded,
      'cleaner_bronze': Icons.eco_rounded,
      'cleaner_silver': Icons.eco_rounded,
      'cleaner_gold': Icons.eco_rounded,
      'century_club': Icons.star_rounded,
      'high_achiever': Icons.emoji_events_rounded,
      'legendary_contributor': Icons.military_tech_rounded,
      'hazard_handler': Icons.warning_rounded,
      'recycling_champion': Icons.recycling_rounded,
      'weekly_warrior': Icons.local_fire_department_rounded,
      'monthly_master': Icons.calendar_month_rounded,
      'top_hundred': Icons.leaderboard_rounded,
      'top_ten': Icons.military_tech_rounded,
      'number_one': Icons.emoji_events_rounded,
    };

    return iconMap[badgeId] ?? Icons.help_rounded;
  }
}
