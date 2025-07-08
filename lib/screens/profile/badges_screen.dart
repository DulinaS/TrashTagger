// lib/screens/profile/badges_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/user_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/loading_widget.dart';

class BadgesScreen extends StatefulWidget {
  @override
  _BadgesScreenState createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  List<Map<String, dynamic>> _allBadges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
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
    } catch (e) {
      print('Error loading badges: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Badges & Achievements'), elevation: 0),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading badges...')
          : Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                final user = userProvider.currentUser;
                if (user == null) {
                  return const Center(child: Text('Unable to load user data'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Summary
                      _buildProgressSummary(user.badges),
                      const SizedBox(height: 24),

                      // Badge Categories
                      _buildBadgeCategories(user.badges),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProgressSummary(List<String> userBadges) {
    final earnedCount = userBadges.length;
    final totalCount = _allBadges.length;
    final progress = totalCount > 0 ? earnedCount / totalCount : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Achievement Progress', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: AppTheme.lightGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              '$earnedCount / $totalCount',
              style: AppTheme.headlineLarge.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            Text('Badges Earned', style: AppTheme.bodyMedium),
            const SizedBox(height: 8),

            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.lightGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '${(progress * 100).toStringAsFixed(1)}% Complete',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('$category Badges', style: AppTheme.headlineMedium),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            final badge = badges[index];
            final isEarned = userBadges.contains(badge['id']);
            return _buildBadgeCard(badge, isEarned);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, bool isEarned) {
    final rarity = badge['rarity'] ?? 'common';
    final rarityColor = _getRarityColor(rarity);

    return Card(
      elevation: isEarned ? 4 : 1,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isEarned
                  ? Border.all(color: rarityColor, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12), // Reduced padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge Icon
                  Container(
                    width: 40, // Slightly smaller icon
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEarned
                          ? rarityColor.withOpacity(0.2)
                          : AppTheme.textSecondary.withOpacity(0.1),
                    ),
                    child: Icon(
                      _getBadgeIcon(badge['id']),
                      size: 24, // Smaller icon size
                      color: isEarned ? rarityColor : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Badge Name
                  Expanded(
                    child: Center(
                      child: Text(
                        badge['name'] ?? 'Unknown',
                        style: AppTheme.labelMedium.copyWith(
                          color: isEarned
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: isEarned
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12, // Smaller font
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2, // Allow 2 lines for longer names
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Points Reward
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : AppTheme.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${badge['pointsAwarded'] ?? 0} pts',
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 10,
                        color: isEarned
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Rarity
                  Text(
                    rarity.toUpperCase(),
                    style: AppTheme.bodyMedium.copyWith(
                      fontSize: 9,
                      color: rarityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lock overlay for unearned badges
          if (!isEarned)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return AppTheme.primaryGreen;
      case 'rare':
        return AppTheme.infoBlue;
      case 'legendary':
        return AppTheme.warningOrange;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getBadgeIcon(String badgeId) {
    final iconMap = {
      'first_report': Icons.flag,
      'first_cleanup': Icons.cleaning_services,
      'reporter_bronze': Icons.report,
      'reporter_silver': Icons.report,
      'reporter_gold': Icons.report,
      'cleaner_bronze': Icons.eco,
      'cleaner_silver': Icons.eco,
      'cleaner_gold': Icons.eco,
      'century_club': Icons.star,
      'high_achiever': Icons.emoji_events,
      'legendary_contributor': Icons.military_tech,
      'hazard_handler': Icons.warning,
      'recycling_champion': Icons.recycling,
      'weekly_warrior': Icons.local_fire_department,
      'monthly_master': Icons.calendar_month,
      'top_hundred': Icons.leaderboard,
      'top_ten': Icons.military_tech,
      'number_one': Icons.emoji_events,
    };

    return iconMap[badgeId] ?? Icons.help;
  }
}
