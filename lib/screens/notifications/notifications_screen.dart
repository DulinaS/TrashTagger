// lib/screens/notifications/notifications_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/loading_widget.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _loadNotifications();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
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

  Future<void> _refreshNotifications() async {
    _refreshController.forward().then((_) {
      _refreshController.reset();
    });
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(),
          _isLoading
              ? SliverToBoxAdapter(
                  child: const LoadingWidget(
                    message: 'Loading notifications...',
                  ),
                )
              : _buildNotificationsContent(),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    final unreadCount = _notifications.where((n) => !n.read).length;

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
                AppTheme.accentCoral.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                ).createShader(bounds),
                child: Text(
                  'Notifications',
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        if (unreadCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Icon(
                  Icons.done_all_rounded,
                  color: AppTheme.primaryEmerald,
                  size: 20,
                ),
              ),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
            onPressed: _refreshNotifications,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsContent() {
    if (_notifications.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    // Group notifications by date
    final groupedNotifications = _groupNotificationsByDate();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final date = groupedNotifications.keys.elementAt(index);
        final notifications = groupedNotifications[date]!;

        return SlideInAnimation(
          delay: Duration(milliseconds: index * 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  _formatDateHeader(date),
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              // Notifications for this date
              ...notifications.asMap().entries.map((entry) {
                final notificationIndex = entry.key;
                final notification = entry.value;
                return SlideInAnimation(
                  delay: Duration(
                    milliseconds: (index * 100) + (notificationIndex * 50),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: _buildNotificationCard(notification),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }, childCount: groupedNotifications.length),
    );
  }

  Widget _buildEmptyState() {
    return SlideInAnimation(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCoral.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Notifications Yet',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ll see notifications about challenges, achievements, and more here.',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.read
              ? AppTheme.borderLight
              : AppTheme.primaryEmerald.withOpacity(0.3),
        ),
        boxShadow: [
          if (!notification.read)
            BoxShadow(
              color: AppTheme.primaryEmerald.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _getNotificationGradient(notification.type),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getNotificationColor(
                          notification.type,
                        ).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: notification.read
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!notification.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.body,
                        style: AppTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Metadata
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(
                                notification.type,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getTypeDisplayName(notification.type),
                              style: AppTheme.labelSmall.copyWith(
                                color: _getNotificationColor(notification.type),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(notification.createdAt),
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          if (notification.isHighPriority) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'URGENT',
                                style: AppTheme.labelSmall.copyWith(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<NotificationModel>> _groupNotificationsByDate() {
    final Map<DateTime, List<NotificationModel>> grouped = {};

    for (final notification in _notifications) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      if (grouped[date] == null) {
        grouped[date] = [];
      }
      grouped[date]!.add(notification);
    }

    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_challenge':
        return Icons.cleaning_services_rounded;
      case 'badge_earned':
        return Icons.military_tech_rounded;
      case 'level_up':
        return Icons.trending_up_rounded;
      case 'leaderboard_update':
        return Icons.leaderboard_rounded;
      case 'verification_result':
        return Icons.verified_rounded;
      case 'challenge_completed':
        return Icons.check_circle_rounded;
      case 'report_status':
        return Icons.assignment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_challenge':
        return AppTheme.primaryTeal;
      case 'badge_earned':
        return AppTheme.accentAmber;
      case 'level_up':
        return AppTheme.accentPurple;
      case 'leaderboard_update':
        return AppTheme.warningAmber;
      case 'verification_result':
        return AppTheme.primaryEmerald;
      case 'challenge_completed':
        return AppTheme.successGreen;
      case 'report_status':
        return AppTheme.infoBlue;
      default:
        return AppTheme.textSecondary;
    }
  }

  LinearGradient _getNotificationGradient(String type) {
    switch (type) {
      case 'new_challenge':
        return LinearGradient(
          colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
        );
      case 'badge_earned':
        return AppTheme.warningGradient;
      case 'level_up':
        return LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        );
      case 'leaderboard_update':
        return LinearGradient(
          colors: [AppTheme.warningAmber, AppTheme.accentAmber],
        );
      case 'verification_result':
        return AppTheme.successGradient;
      case 'challenge_completed':
        return AppTheme.primaryGradient;
      case 'report_status':
        return LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        );
      default:
        return LinearGradient(
          colors: [AppTheme.textSecondary, AppTheme.textTertiary],
        );
    }
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'new_challenge':
        return 'New Challenge';
      case 'badge_earned':
        return 'Badge Earned';
      case 'level_up':
        return 'Level Up';
      case 'leaderboard_update':
        return 'Leaderboard';
      case 'verification_result':
        return 'Verification';
      case 'challenge_completed':
        return 'Completed';
      case 'report_status':
        return 'Report Update';
      default:
        return 'Notification';
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
    // Add navigation logic here based on action type
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.done_all_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('All notifications marked as read'),
            ],
          ),
          backgroundColor: AppTheme.primaryEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
}
