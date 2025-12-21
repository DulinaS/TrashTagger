// lib/utils/helpers.dart - Updated with correct color references
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:trash_tagger/themes/app_theme.dart';

class Helpers {
  // Format timestamp
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Format timestamp with full date
  static String formatFullDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(dateTime);
  }

  // Format date only
  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM d, y').format(dateTime);
  }

  // Format time only
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  // Format points with commas
  static String formatPoints(int points) {
    if (points >= 1000000) {
      return '${(points / 1000000).toStringAsFixed(1)}M';
    } else if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}K';
    } else {
      return NumberFormat('#,###').format(points);
    }
  }

  // Format large numbers with K/M suffixes
  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  // Get trash type display name
  static String getTrashTypeDisplayName(String type) {
    switch (type) {
      case 'general':
        return 'General Waste';
      case 'recyclable':
        return 'Recyclable';
      case 'hazardous':
        return 'Hazardous';
      case 'large':
        return 'Large Items';
      case 'organic':
        return 'Organic Waste';
      default:
        return 'Unknown';
    }
  }

  // Get trash type description
  static String getTrashTypeDescription(String type) {
    switch (type) {
      case 'general':
        return 'Common waste like food wrappers, papers, bottles, etc.';
      case 'recyclable':
        return 'Plastic bottles, cans, cardboard that can be recycled';
      case 'hazardous':
        return 'Chemicals, batteries, medical waste - requires special handling';
      case 'large':
        return 'Furniture, appliances, large items that need special pickup';
      case 'organic':
        return 'Food waste, leaves, compostable materials';
      default:
        return 'Unknown waste type';
    }
  }

  // Get severity color (updated with correct AppTheme colors)
  static Color getSeverityColor(String severity) {
    switch (severity) {
      case 'low':
        return AppTheme.successGreen;
      case 'medium':
        return AppTheme.warningAmber;
      case 'high':
        return AppTheme.errorRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  // Get severity display name
  static String getSeverityDisplayName(String severity) {
    switch (severity) {
      case 'low':
        return 'Low Priority';
      case 'medium':
        return 'Medium Priority';
      case 'high':
        return 'High Priority';
      default:
        return 'Unknown';
    }
  }

  // Get severity description
  static String getSeverityDescription(String severity) {
    switch (severity) {
      case 'low':
        return 'Small amount, easy to clean (5-15 min)';
      case 'medium':
        return 'Moderate amount, requires some effort (15-30 min)';
      case 'high':
        return 'Large amount or difficult to clean (30+ min)';
      default:
        return 'Unknown severity level';
    }
  }

  // Get status color
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningAmber;
      case 'verified':
        return AppTheme.successGreen;
      case 'cleaning':
        return AppTheme.infoBlue;
      case 'completed':
        return AppTheme.primaryEmerald;
      case 'rejected':
        return AppTheme.errorRed;
      case 'disputed':
        return AppTheme.accentCoral;
      default:
        return AppTheme.textTertiary;
    }
  }

  // Get status display name
  static String getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'verified':
        return 'Verified';
      case 'cleaning':
        return 'Being Cleaned';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'disputed':
        return 'Disputed';
      default:
        return 'Unknown Status';
    }
  }

  // Calculate distance string
  static String formatDistance(double distanceKm) {
    if (distanceKm < 0.1) {
      return 'Very close';
    } else if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  // Calculate level from points
  static int calculateLevel(int points) {
    if (points < 50) return 1;
    if (points < 150) return 2;
    if (points < 300) return 3;
    if (points < 500) return 4;
    if (points < 1000) return 5;
    // After level 5, each level requires 200 more points
    return 5 + ((points - 1000) / 200).floor();
  }

  // Get points needed for next level
  static int getPointsForNextLevel(int currentPoints) {
    final currentLevel = calculateLevel(currentPoints);
    return getPointsRequiredForLevel(currentLevel + 1) - currentPoints;
  }

  // Get total points required for a specific level
  static int getPointsRequiredForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 50;
    if (level == 3) return 150;
    if (level == 4) return 300;
    if (level == 5) return 500;
    if (level == 6) return 1000;
    // After level 6, each level requires 200 more points than the previous
    return 1000 + ((level - 6) * 200);
  }

  // Calculate level progress (0.0 to 1.0)
  static double calculateLevelProgress(int points) {
    final currentLevel = calculateLevel(points);
    final currentLevelPoints = getPointsRequiredForLevel(currentLevel);
    final nextLevelPoints = getPointsRequiredForLevel(currentLevel + 1);

    if (points >= nextLevelPoints) return 1.0;

    final progressPoints = points - currentLevelPoints;
    final totalPointsNeeded = nextLevelPoints - currentLevelPoints;

    return progressPoints / totalPointsNeeded;
  }

  // Get badge rarity color
  static Color getBadgeRarityColor(String rarity) {
    switch (rarity) {
      case 'common':
        return AppTheme.textSecondary;
      case 'uncommon':
        return AppTheme.successGreen;
      case 'rare':
        return AppTheme.infoBlue;
      case 'epic':
        return AppTheme.accentPurple;
      case 'legendary':
        return AppTheme.accentAmber;
      default:
        return AppTheme.textSecondary;
    }
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Validate email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Validate phone number (basic)
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone.replaceAll(' ', ''));
  }

  // Generate random ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Get time ago with relative formatting
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Check if date is today
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  // Check if date is yesterday
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  // Get greeting based on time of day
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  // Calculate estimated cleanup time
  static String getEstimatedCleanupTime(String severity) {
    switch (severity) {
      case 'low':
        return '5-15 minutes';
      case 'medium':
        return '15-30 minutes';
      case 'high':
        return '30+ minutes';
      default:
        return 'Unknown';
    }
  }

  // Get effort level points
  static int getEffortPoints(String severity) {
    switch (severity) {
      case 'low':
        return 20;
      case 'medium':
        return 30;
      case 'high':
        return 50;
      default:
        return 10;
    }
  }

  // Format duration
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
