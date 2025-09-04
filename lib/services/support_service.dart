// lib/services/support_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupportService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a support message
  static Future<String> submitSupportMessage({
    required String subject,
    required String message,
    required String category,
    String priority = 'medium',
    List<String> attachments = const [],
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'submitSupportMessage',
      );

      final result = await callable.call({
        'subject': subject,
        'message': message,
        'category': category,
        'priority': priority,
        'attachments': attachments,
      });

      if (result.data['success'] == true) {
        return result.data['messageId'];
      } else {
        throw Exception(
          result.data['message'] ?? 'Failed to submit support message',
        );
      }
    } catch (e) {
      throw Exception('Error submitting support message: $e');
    }
  }

  // Get user's support messages
  static Future<List<Map<String, dynamic>>> getUserSupportMessages({
    int limit = 10,
    String status = 'all',
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'getUserSupportMessages',
      );

      final result = await callable.call({'limit': limit, 'status': status});

      if (result.data['success'] == true) {
        return List<Map<String, dynamic>>.from(result.data['messages']);
      } else {
        throw Exception('Failed to get support messages');
      }
    } catch (e) {
      throw Exception('Error getting support messages: $e');
    }
  }

  // Get real-time updates for user's support messages
  static Stream<List<Map<String, dynamic>>> getUserSupportMessagesStream(
    String userId,
  ) {
    return _firestore
        .collection('supportMessages')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }

  // Categories for support messages
  static const Map<String, String> categories = {
    'bug': 'Bug Report',
    'feature': 'Feature Request',
    'account': 'Account Issue',
    'technical': 'Technical Problem',
    'general': 'General Question',
  };

  // Priority levels
  static const Map<String, String> priorities = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
  };

  // Status types
  static const Map<String, String> statusTypes = {
    'open': 'Open',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  // Get display name for category
  static String getCategoryDisplayName(String category) {
    return categories[category] ?? category;
  }

  // Get display name for priority
  static String getPriorityDisplayName(String priority) {
    return priorities[priority] ?? priority;
  }

  // Get display name for status
  static String getStatusDisplayName(String status) {
    return statusTypes[status] ?? status;
  }

  // Get color for priority
  static String getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return 'blue';
      case 'medium':
        return 'orange';
      case 'high':
        return 'red';
      default:
        return 'gray';
    }
  }

  // Get color for status
  static String getStatusColor(String status) {
    switch (status) {
      case 'open':
        return 'blue';
      case 'in_progress':
        return 'orange';
      case 'resolved':
        return 'green';
      case 'closed':
        return 'gray';
      default:
        return 'gray';
    }
  }
}
