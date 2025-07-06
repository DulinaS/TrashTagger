// lib/utils/helpers.dart
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

  // Format points with commas
  static String formatPoints(int points) {
    return NumberFormat('#,###').format(points);
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

  // Get severity color
  static Color getSeverityColor(String severity) {
    switch (severity) {
      case 'low':
        return AppTheme.primaryGreen;
      case 'medium':
        return AppTheme.warningOrange;
      case 'high':
        return AppTheme.dangerRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  // Calculate distance string
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()}m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km away';
    }
  }

  // Calculate level from points
  static int calculateLevel(int points) {
    if (points < 50) return 1;
    if (points < 150) return 2;
    if (points < 300) return 3;
    if (points < 500) return 4;
    if (points < 1000) return 5;
    return (points / 200).floor() + 1;
  }
}
