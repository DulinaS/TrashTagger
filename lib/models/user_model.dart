import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoURL;
  final int totalPoints;
  final List<String> badges;
  final int level;
  final DateTime joinDate;
  final DateTime lastActive;
  final UserSettings settings;
  final UserStats stats;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoURL,
    required this.totalPoints,
    required this.badges,
    required this.level,
    required this.joinDate,
    required this.lastActive,
    required this.settings,
    required this.stats,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      photoURL: map['photoURL'],
      totalPoints: map['totalPoints'] ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      level: map['level'] ?? 1,
      joinDate: (map['joinDate'] as Timestamp).toDate(),
      lastActive: (map['lastActive'] as Timestamp).toDate(),
      settings: UserSettings.fromMap(map['settings'] ?? {}),
      stats: UserStats.fromMap(map['stats'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoURL': photoURL,
      'totalPoints': totalPoints,
      'badges': badges,
      'level': level,
      'joinDate': Timestamp.fromDate(joinDate),
      'lastActive': Timestamp.fromDate(lastActive),
      'settings': settings.toMap(),
      'stats': stats.toMap(),
    };
  }
}

class UserSettings {
  final bool notificationsEnabled;
  final double radius;
  final bool safetyWarningsEnabled;

  UserSettings({
    required this.notificationsEnabled,
    required this.radius,
    required this.safetyWarningsEnabled,
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      radius: map['radius']?.toDouble() ?? 5.0,
      safetyWarningsEnabled: map['safetyWarningsEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'radius': radius,
      'safetyWarningsEnabled': safetyWarningsEnabled,
    };
  }
}

class UserStats {
  final int reportsSubmitted;
  final int challengesCompleted;
  final int weeklyStreak;
  final int monthlyPoints;

  UserStats({
    required this.reportsSubmitted,
    required this.challengesCompleted,
    required this.weeklyStreak,
    required this.monthlyPoints,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      reportsSubmitted: map['reportsSubmitted'] ?? 0,
      challengesCompleted: map['challengesCompleted'] ?? 0,
      weeklyStreak: map['weeklyStreak'] ?? 0,
      monthlyPoints: map['monthlyPoints'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportsSubmitted': reportsSubmitted,
      'challengesCompleted': challengesCompleted,
      'weeklyStreak': weeklyStreak,
      'monthlyPoints': monthlyPoints,
    };
  }
}
