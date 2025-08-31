import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/loading_widget.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).user?.uid;
      if (userId != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        _notifications = snapshot.docs
            .map(
              (doc) => NotificationModel.fromMap({'id': doc.id, ...doc.data()}),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark All Read'),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading notifications...')
          : _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Notifications Yet',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see notifications about challenges, achievements, and more here.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        return _buildNotificationItem(_notifications[index]);
      },
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.read ? null : AppTheme.primaryGreen.withOpacity(0.05),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: notification.isHighPriority
                ? AppTheme.primaryGreen.withOpacity(0.2)
                : AppTheme.textSecondary.withOpacity(0.1),
          ),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: notification.isHighPriority
                ? AppTheme.primaryGreen
                : AppTheme.textSecondary,
          ),
        ),
        title: Text(
          notification.title,
          style: AppTheme.labelMedium.copyWith(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(notification.createdAt),
              style: AppTheme.bodyMedium.copyWith(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
        trailing: !notification.read
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen,
                ),
              )
            : null,
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_challenge':
        return Icons.cleaning_services;
      case 'badge_earned':
        return Icons.military_tech;
      case 'level_up':
        return Icons.trending_up;
      case 'leaderboard_update':
        return Icons.leaderboard;
      case 'verification_result':
        return Icons.verified;
      default:
        return Icons.notifications;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.read) {
      _markAsRead(notification.id);
    }

    // Handle navigation based on notification data
    final action = notification.data['action'] as String?;
    // Use NotificationService navigation logic here
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(read: true);
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final notification in _notifications.where((n) => !n.read)) {
        batch.update(
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(notification.id),
          {'read': true},
        );
      }
      await batch.commit();

      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(read: true))
            .toList();
      });
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
}
