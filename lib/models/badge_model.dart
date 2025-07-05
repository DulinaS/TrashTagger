// lib/models/badge_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/models/user_model.dart';

enum BadgeType {
  milestone, // Achievement based on numbers (10 cleanups, 100 points)
  streak, // Consecutive actions (weekly streak)
  special, // Special events or accomplishments
  rank, // Based on leaderboard position
}

enum BadgeRarity {
  common, // Easy to get, most users will achieve
  uncommon, // Requires some effort
  rare, // Difficult to achieve
  legendary, // Very rare, top performers only
}

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String iconURL;
  final BadgeType type;
  final BadgeRarity rarity;
  final BadgeCriteria criteria;
  final int pointsAwarded;
  final bool isActive;
  final DateTime createdAt;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconURL,
    required this.type,
    required this.rarity,
    required this.criteria,
    required this.pointsAwarded,
    required this.isActive,
    required this.createdAt,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map) {
    return BadgeModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconURL: map['iconURL'] ?? '',
      type: BadgeType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BadgeType.milestone,
      ),
      rarity: BadgeRarity.values.firstWhere(
        (e) => e.name == map['rarity'],
        orElse: () => BadgeRarity.common,
      ),
      criteria: BadgeCriteria.fromMap(map['criteria'] ?? {}),
      pointsAwarded: map['pointsAwarded'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconURL': iconURL,
      'type': type.name,
      'rarity': rarity.name,
      'criteria': criteria.toMap(),
      'pointsAwarded': pointsAwarded,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Get color based on rarity
  String get rarityColor {
    switch (rarity) {
      case BadgeRarity.common:
        return '#808080'; // Gray
      case BadgeRarity.uncommon:
        return '#00FF00'; // Green
      case BadgeRarity.rare:
        return '#0080FF'; // Blue
      case BadgeRarity.legendary:
        return '#FF8000'; // Orange
    }
  }
}

class BadgeCriteria {
  final int? reportsRequired;
  final int? cleanupsRequired;
  final int? pointsRequired;
  final int? streakRequired;
  final int? leaderboardPosition;
  final List<String>? specificTrashTypes;
  final String? timeFrame; // 'daily', 'weekly', 'monthly'
  final Map<String, dynamic>? customCriteria;

  BadgeCriteria({
    this.reportsRequired,
    this.cleanupsRequired,
    this.pointsRequired,
    this.streakRequired,
    this.leaderboardPosition,
    this.specificTrashTypes,
    this.timeFrame,
    this.customCriteria,
  });

  factory BadgeCriteria.fromMap(Map<String, dynamic> map) {
    return BadgeCriteria(
      reportsRequired: map['reportsRequired'],
      cleanupsRequired: map['cleanupsRequired'],
      pointsRequired: map['pointsRequired'],
      streakRequired: map['streakRequired'],
      leaderboardPosition: map['leaderboardPosition'],
      specificTrashTypes: map['specificTrashTypes'] != null
          ? List<String>.from(map['specificTrashTypes'])
          : null,
      timeFrame: map['timeFrame'],
      customCriteria: map['customCriteria'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportsRequired': reportsRequired,
      'cleanupsRequired': cleanupsRequired,
      'pointsRequired': pointsRequired,
      'streakRequired': streakRequired,
      'leaderboardPosition': leaderboardPosition,
      'specificTrashTypes': specificTrashTypes,
      'timeFrame': timeFrame,
      'customCriteria': customCriteria,
    };
  }

  // Check if user meets the criteria
  bool isMetBy(
    UserStats stats,
    int totalPoints, {
    int? currentStreak,
    int? leaderboardRank,
  }) {
    // Check reports required
    if (reportsRequired != null && stats.reportsSubmitted < reportsRequired!) {
      return false;
    }

    // Check cleanups required
    if (cleanupsRequired != null &&
        stats.challengesCompleted < cleanupsRequired!) {
      return false;
    }

    // Check points required
    if (pointsRequired != null && totalPoints < pointsRequired!) {
      return false;
    }

    // Check streak required
    if (streakRequired != null && (currentStreak ?? 0) < streakRequired!) {
      return false;
    }

    // Check leaderboard position
    if (leaderboardPosition != null &&
        (leaderboardRank ?? 999999) > leaderboardPosition!) {
      return false;
    }

    return true;
  }
}

// User's badge progress
class UserBadgeProgress {
  final String badgeId;
  final String userId;
  final double progress; // 0.0 to 1.0
  final DateTime lastUpdated;
  final bool isEarned;
  final DateTime? earnedAt;

  UserBadgeProgress({
    required this.badgeId,
    required this.userId,
    required this.progress,
    required this.lastUpdated,
    required this.isEarned,
    this.earnedAt,
  });

  factory UserBadgeProgress.fromMap(Map<String, dynamic> map) {
    return UserBadgeProgress(
      badgeId: map['badgeId'] ?? '',
      userId: map['userId'] ?? '',
      progress: (map['progress'] ?? 0.0).toDouble(),
      lastUpdated:
          (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEarned: map['isEarned'] ?? false,
      earnedAt: map['earnedAt'] != null
          ? (map['earnedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'badgeId': badgeId,
      'userId': userId,
      'progress': progress,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isEarned': isEarned,
      'earnedAt': earnedAt != null ? Timestamp.fromDate(earnedAt!) : null,
    };
  }

  // Calculate progress percentage
  int get progressPercentage => (progress * 100).round();
}

// Predefined badges for the app
/* class BadgeDefinitions {
  static List<BadgeModel> getDefaultBadges() {
    return [
      // Milestone badges
      BadgeModel(
        id: 'first_report',
        name: 'First Step',
        description: 'Submit your first trash report',
        iconURL: 'assets/badges/first_report.png',
        type: BadgeType.milestone,
        rarity: BadgeRarity.common,
        criteria: BadgeCriteria(reportsRequired: 1),
        pointsAwarded: 10,
        isActive: true,
        createdAt: DateTime.now(),
      ),

      BadgeModel(
        id: 'first_cleanup',
        name: 'Cleanup Hero',
        description: 'Complete your first cleanup challenge',
        iconURL: 'assets/badges/first_cleanup.png',
        type: BadgeType.milestone,
        rarity: BadgeRarity.common,
        criteria: BadgeCriteria(cleanupsRequired: 1),
        pointsAwarded: 25,
        isActive: true,
        createdAt: DateTime.now(),
      ),

      BadgeModel(
        id: 'reporter_bronze',
        name: 'Bronze Reporter',
        description: 'Submit 10 trash reports',
        iconURL: 'assets/badges/reporter_bronze.png',
        type: BadgeType.milestone,
        rarity: BadgeRarity.uncommon,
        criteria: BadgeCriteria(reportsRequired: 10),
        pointsAwarded: 50,
        isActive: true,
        createdAt: DateTime.now(),
      ),

      BadgeModel(
        id: 'cleaner_bronze',
        name: 'Bronze Cleaner',
        description: 'Complete 5 cleanup challenges',
        iconURL: 'assets/badges/cleaner_bronze.png',
        type: BadgeType.milestone,
        rarity: BadgeRarity.uncommon,
        criteria: BadgeCriteria(cleanupsRequired: 5),
        pointsAwarded: 75,
        isActive: true,
        createdAt: DateTime.now(),
      ),

      // Streak badges
      BadgeModel(
        id: 'weekly_warrior',
        name: 'Weekly Warrior',
        description: 'Complete cleanup challenges for 7 consecutive days',
        iconURL: 'assets/badges/weekly_warrior.png',
        type: BadgeType.streak,
        rarity: BadgeRarity.rare,
        criteria: BadgeCriteria(streakRequired: 7, timeFrame: 'daily'),
        pointsAwarded: 100,
        isActive: true,
        createdAt: DateTime.now(),
      ),

      // Special badges
      BadgeModel(
        id: 'hazard_handler',
        name: 'Hazard Handler',
        description: 'Clean up hazardous waste safely',
        iconURL: 'assets/badges/hazard_handler.png',
        type: BadgeType.special,
        rarity: BadgeRarity.rare,
        criteria: BadgeCriteria(
          cleanupsRequired: 1,
          specificTrashTypes: ['hazardous'],
        ),
        pointsAwarded: 150,
        isActive: true,
        createdAt: DateTime.now(),
      ),

      // Rank badges
      BadgeModel(
        id: 'top_ten',
        name: 'Top 10',
        description: 'Reach top 10 on the leaderboard',
        iconURL: 'assets/badges/top_ten.png',
        type: BadgeType.rank,
        rarity: BadgeRarity.legendary,
        criteria: BadgeCriteria(leaderboardPosition: 10),
        pointsAwarded: 250,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];
  }
}
 */
