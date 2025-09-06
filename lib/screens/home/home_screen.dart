// lib/screens/home/home_screen.dart - Fixed Animation Initialization
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/main.dart';
import 'dart:math' as math;
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../models/trash_report_model.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/page_transitions.dart';
import '../test/notification_test_screen.dart';
import 'main_ navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isLoadingReports = false;
  List<TrashReportModel> _userReports = [];
  List<TrashReportModel> _recentActivity = [];
  int _unreadNotificationCount = 0;

  // Animation controllers - Initialize as nullable first
  AnimationController? _refreshController;
  AnimationController? _statsController;
  AnimationController? _waveController;
  AnimationController? _floatingController;
  AnimationController? _gradientController;
  AnimationController? _parallaxController;

  // Animations - Initialize as nullable first
  Animation<double>? _waveAnimation;
  Animation<double>? _floatingAnimation;
  Animation<double>? _gradientAnimation;
  Animation<double>? _parallaxAnimation;

  // Getters to safely access animations
  Animation<double> get waveAnimation =>
      _waveAnimation ?? AlwaysStoppedAnimation(0.0);
  Animation<double> get floatingAnimation =>
      _floatingAnimation ?? AlwaysStoppedAnimation(0.0);
  Animation<double> get gradientAnimation =>
      _gradientAnimation ?? AlwaysStoppedAnimation(0.0);
  Animation<double> get parallaxAnimation =>
      _parallaxAnimation ?? AlwaysStoppedAnimation(0.0);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadUnreadNotificationCount();
      _setupNotificationListener();
      _startAnimations();
    });
  }

  void _initializeAnimations() {
    // Initialize all animation controllers first
    _refreshController = AnimationController(
      duration: AnimationConstants.refreshDuration,
      vsync: this,
    );

    _statsController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _gradientController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _parallaxController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    // Then initialize all animations using the controllers
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _waveController!, curve: Curves.linear));

    _floatingAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _floatingController!, curve: Curves.easeInOut),
    );

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController!, curve: Curves.easeInOut),
    );

    _parallaxAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _parallaxController!, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) {
        _statsController?.forward();
        _waveController?.repeat();
        _floatingController?.repeat(reverse: true);
        _gradientController?.repeat(reverse: true);
        _parallaxController?.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshController?.dispose();
    _statsController?.dispose();
    _waveController?.dispose();
    _floatingController?.dispose();
    _gradientController?.dispose();
    _parallaxController?.dispose();
    super.dispose();
  }

  void _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadCurrentUser(authProvider.user!.uid);

      await _loadUserReports(authProvider.user!.uid);
      await _loadRecentActivity();
    }
  }

  void _loadUnreadNotificationCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        final count = await NotificationService.getUnreadCount(
          authProvider.user!.uid,
        );
        if (mounted) {
          setState(() {
            _unreadNotificationCount = count;
          });
        }
      } catch (e) {
        debugPrint('Error loading unread notification count: $e');
      }
    }
  }

  void _setupNotificationListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: authProvider.user!.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                _unreadNotificationCount = snapshot.docs.length;
              });
            }
          });
    }
  }

  Future<void> _loadUserReports(String userId) async {
    setState(() => _isLoadingReports = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('reporterId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      _userReports = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id,
              ...doc.data(),
            }),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading user reports: $e');
    }

    setState(() => _isLoadingReports = false);
  }

  Future<void> _loadRecentActivity() async {
    try {
      final yesterday = DateTime.now().subtract(Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', isEqualTo: 'verified')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      _recentActivity = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id,
              ...doc.data(),
            }),
          )
          .toList();

      setState(() {});
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
    }
  }

  void _navigateToNotifications() {
    Navigator.of(context)
        .push(
          PageTransitions.slideFromRight(
            page: NotificationsScreen(),
            duration: AnimationConstants.mediumDuration,
          ),
        )
        .then((_) {
          _loadUnreadNotificationCount();
        });
  }

  void _navigateToTab(int tabIndex) {
    mainNavKey.currentState?.onTabTapped(tabIndex);
  }

  Future<void> _refreshData() async {
    _refreshController?.forward().then((_) {
      _refreshController?.reset();
    });

    _loadData();
    _loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),

          // Wave animation overlay
          _buildWaveOverlay(),

          // Floating particles
          _buildFloatingParticles(),

          // Main content
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [_buildModernAppBar()];
            },
            body: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (userProvider.isLoading) {
                  return const ModernLoadingWidget(
                    message: 'Loading your profile...',
                  );
                }

                final user = userProvider.currentUser;
                if (user == null) {
                  return ModernEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to Load Profile',
                    message: 'Please try again or restart the app.',
                    actionText: 'Retry',
                    onAction: _refreshData,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Section with parallax
                              _buildParallaxWrapper(
                                child: SlideInAnimation(
                                  delay: AnimationConstants.microDelay,
                                  child: _buildWelcomeSection(user),
                                ),
                                offset: 0.1,
                              ),
                              const SizedBox(height: 24),

                              // Quick Stats with floating effect
                              _buildFloatingWrapper(
                                child: StaggeredListAnimation(
                                  itemDelay: const Duration(milliseconds: 80),
                                  children: [_buildQuickStats(user)],
                                ),
                                offset: 0.05,
                              ),
                              const SizedBox(height: 24),

                              // Notifications Preview
                              if (_unreadNotificationCount > 0) ...[
                                _buildParallaxWrapper(
                                  child: SlideInAnimation(
                                    delay: AnimationConstants.mediumDelay,
                                    child: _buildNotificationPreview(),
                                  ),
                                  offset: 0.08,
                                ),
                                const SizedBox(height: 24),
                              ],

                              // My Reports Section
                              _buildFloatingWrapper(
                                child: SlideInAnimation(
                                  delay: AnimationConstants.longDelay,
                                  child: _buildMyReportsSection(),
                                ),
                                offset: 0.03,
                              ),
                              const SizedBox(height: 24),

                              // Recent Activity
                              _buildParallaxWrapper(
                                child: SlideInAnimation(
                                  delay: AnimationConstants.extraLongDelay,
                                  child: _buildRecentActivity(),
                                ),
                                offset: 0.06,
                              ),
                              const SizedBox(height: 24),

                              // Quick Actions with enhanced animations
                              _buildFloatingWrapper(
                                child: ScaleInAnimation(
                                  delay: const Duration(milliseconds: 600),
                                  child: _buildQuickActions(),
                                ),
                                offset: 0.04,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // New animated background with shifting gradients
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: gradientAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryEmerald.withOpacity(
                  0.1 + 0.05 * gradientAnimation.value,
                ),
                AppTheme.accentPurple.withOpacity(
                  0.05 + 0.03 * gradientAnimation.value,
                ),
                AppTheme.primaryTeal.withOpacity(
                  0.08 + 0.04 * gradientAnimation.value,
                ),
              ],
              stops: [
                0.0 + 0.2 * gradientAnimation.value,
                0.5 + 0.2 * math.sin(gradientAnimation.value * math.pi),
                1.0 - 0.1 * gradientAnimation.value,
              ],
            ),
          ),
        );
      },
    );
  }

  // Wave animation overlay
  Widget _buildWaveOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: waveAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: WavePainter(
              animationValue: waveAnimation.value,
              color: AppTheme.primaryEmerald.withOpacity(0.05),
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  // Floating particles effect
  Widget _buildFloatingParticles() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: floatingAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(
              animationValue: floatingAnimation.value,
              color: AppTheme.primaryEmerald.withOpacity(0.3),
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  // Parallax wrapper for elements
  Widget _buildParallaxWrapper({
    required Widget child,
    required double offset,
  }) {
    return AnimatedBuilder(
      animation: parallaxAnimation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(
            0,
            math.sin(parallaxAnimation.value * 2 * math.pi) * offset * 20,
          ),
          child: child,
        );
      },
    );
  }

  // Floating wrapper for elements
  Widget _buildFloatingWrapper({
    required Widget child,
    required double offset,
  }) {
    return AnimatedBuilder(
      animation: floatingAnimation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(
            math.sin(floatingAnimation.value) * offset * 10,
            math.cos(floatingAnimation.value * 0.8) * offset * 15,
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary.withOpacity(0.95),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: gradientAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryEmerald.withOpacity(
                      0.1 + 0.05 * gradientAnimation.value,
                    ),
                    AppTheme.accentPurple.withOpacity(
                      0.05 + 0.03 * gradientAnimation.value,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        title: _buildFloatingWrapper(
          child: Row(
            children: [
              AnimatedBuilder(
                animation: floatingAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: math.sin(floatingAnimation.value) * 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryEmerald.withOpacity(0.3),
                            blurRadius:
                                8 + 4 * math.sin(floatingAnimation.value),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    'TrashTagger',
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
          offset: 0.02,
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        // Animated notification button
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedBuilder(
            animation: floatingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + 0.05 * math.sin(floatingAnimation.value * 2),
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryEmerald.withOpacity(0.1),
                            blurRadius:
                                4 + 2 * math.sin(floatingAnimation.value),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: AppTheme.textPrimary,
                        ),
                        onPressed: _navigateToNotifications,
                      ),
                    ),
                    if (_unreadNotificationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: PulseAnimation(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.errorGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              _unreadNotificationCount > 99
                                  ? '99+'
                                  : _unreadNotificationCount.toString(),
                              style: AppTheme.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        // Debug notification button with enhanced animation
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: AnimatedBuilder(
              animation: floatingAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: math.sin(floatingAnimation.value) * 0.1,
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.bug_report,
                        color: AppTheme.warningAmber,
                      ),
                      onPressed: () async {
                        await NotificationService.sendTestNotification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                const Text('Test notification sent!'),
                              ],
                            ),
                            backgroundColor: AppTheme.primaryEmerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // Enhanced welcome section with micro-interactions
  Widget _buildWelcomeSection(user) {
    return AnimatedBuilder(
      animation: floatingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + 0.02 * math.sin(floatingAnimation.value),
          child: ModernCard(
            padding: const EdgeInsets.all(24),
            enableGlassmorphism: false,
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowLight,
                blurRadius: 10 + 5 * math.sin(floatingAnimation.value),
                offset: Offset(0, 4 + 2 * math.sin(floatingAnimation.value)),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: waveAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: math.sin(waveAnimation.value) * 0.05,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryEmerald.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius:
                                      12 + 4 * math.sin(waveAnimation.value),
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: user.photoURL != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      user.photoURL!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'U',
                                      style: AppTheme.headlineMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.name,
                            style: AppTheme.headlineMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          AnimatedBuilder(
                            animation: gradientAnimation,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryEmerald,
                                      AppTheme.primaryTeal,
                                      AppTheme.accentPurple,
                                    ],
                                    stops: [
                                      0.0,
                                      0.5 + 0.3 * gradientAnimation.value,
                                      1.0,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Level ${user.level} • ${Helpers.formatPoints(user.totalPoints)} pts',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Enhanced level progress with wave animation
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Progress to Level ${user.level + 1}',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${_getPointsToNextLevel(user.totalPoints, user.level)} pts to go',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: waveAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.borderLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _calculateLevelProgress(
                              user.totalPoints,
                              user.level,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryEmerald,
                                    AppTheme.primaryTeal,
                                  ],
                                  stops: [
                                    0.0,
                                    0.5 + 0.3 * math.sin(waveAnimation.value),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryEmerald.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius:
                                        4 + 2 * math.sin(waveAnimation.value),
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Continue with the rest of your existing methods with the same fixes...
  // (All the other methods from your original code with proper null-safe animation access)

  Widget _buildQuickStats(user) {
    final stats = [
      {
        'label': 'Reports',
        'value': _userReports.length.toString(),
        'icon': Icons.report_outlined,
        'color': AppTheme.infoBlue,
        'gradient': LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        ),
      },
      {
        'label': 'Cleanups',
        'value': user.stats.challengesCompleted.toString(),
        'icon': Icons.cleaning_services_outlined,
        'color': AppTheme.primaryEmerald,
        'gradient': AppTheme.successGradient,
      },
      {
        'label': 'Badges',
        'value': user.badges.length.toString(),
        'icon': Icons.military_tech_outlined,
        'color': AppTheme.accentAmber,
        'gradient': AppTheme.warningGradient,
      },
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < stats.length - 1 ? 12 : 0),
            child: ScaleInAnimation(
              delay: Duration(milliseconds: 200 + (index * 100)),
              child: _buildStatCard(
                stat['label'] as String,
                stat['value'] as String,
                stat['icon'] as IconData,
                stat['gradient'] as LinearGradient,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    LinearGradient gradient,
  ) {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: gradient.colors.first,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return ModernCard(
      onTap: _navigateToNotifications,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
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
                    'You have $_unreadNotificationCount new notification${_unreadNotificationCount == 1 ? '' : 's'}',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view updates about challenges, badges, and more',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
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
    );
  }

  Widget _buildMyReportsSection() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'My Reports',
                        style: AppTheme.headlineMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_userReports.isNotEmpty)
                TextButton(
                  onPressed: () => _navigateToTab(1),
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

          if (_isLoadingReports)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ModernLoadingWidget(message: 'Loading reports...'),
              ),
            )
          else if (_userReports.isEmpty)
            _buildEmptyReports()
          else
            Column(
              children: _userReports
                  .take(3)
                  .map((report) => _buildReportItem(report))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyReports() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScaleInAnimation(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reports yet',
            style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by reporting some trash in your area!',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ModernGradientButton(
            text: 'Report Trash',
            onPressed: () => _navigateToTab(2),
            icon: Icons.camera_alt_rounded,
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.getSeverityGradient(report.severity),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getTrashTypeIcon(report.trashType),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Helpers.getTrashTypeDisplayName(report.trashType),
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.address,
                  style: AppTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  Helpers.formatDateTime(report.timestamp),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          ModernStatusBadge(
            status: report.status,
            showPulse: report.status == 'pending',
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.successGreen, AppTheme.primaryEmerald],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.eco_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Community Activity',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_recentActivity.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent activity',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Be the first to report trash today!',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _recentActivity
                  .take(3)
                  .map((report) => _buildActivityItem(report))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(TrashReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppTheme.successGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New ${report.trashType} report',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${Helpers.formatDateTime(report.timestamp)} • ${report.address}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppTheme.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': 'Report Trash',
        'subtitle': 'Take photo & report',
        'icon': Icons.camera_alt_rounded,
        'gradient': AppTheme.primaryGradient,
        'onTap': () => _navigateToTab(2),
      },
      {
        'title': 'Find Cleanup',
        'subtitle': 'Help clean up nearby',
        'icon': Icons.search_rounded,
        'gradient': LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        ),
        'onTap': () => _navigateToTab(3),
      },
      {
        'title': 'View Map',
        'subtitle': 'See nearby reports',
        'icon': Icons.map_outlined,
        'gradient': AppTheme.warningGradient,
        'onTap': () => _navigateToTab(1),
      },
      {
        'title': 'My Profile',
        'subtitle': 'View achievements',
        'icon': Icons.person_outlined,
        'gradient': LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        ),
        'onTap': () => _navigateToTab(4),
      },
    ];

    if (kDebugMode) {
      actions.add({
        'title': 'Test Notifications',
        'subtitle': 'Debug notification system',
        'icon': Icons.bug_report,
        'gradient': AppTheme.errorGradient,
        'onTap': () {
          Navigator.push(
            context,
            PageTransitions.slideFromRight(page: NotificationTestScreen()),
          );
        },
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return ScaleInAnimation(
              delay: Duration(milliseconds: 100 + (index * 50)),
              child: _buildActionCard(
                action['title'] as String,
                action['subtitle'] as String,
                action['icon'] as IconData,
                action['gradient'] as LinearGradient,
                action['onTap'] as VoidCallback,
              ),
            );
          },
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
    return ModernCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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

  IconData _getTrashTypeIcon(String trashType) {
    switch (trashType) {
      case 'general':
        return Icons.delete_rounded;
      case 'recyclable':
        return Icons.recycling_rounded;
      case 'hazardous':
        return Icons.warning_rounded;
      case 'large':
        return Icons.chair_rounded;
      case 'organic':
        return Icons.eco_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}

// Custom painters for wave and particle effects
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 30.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height * 0.8);

    for (double x = 0; x <= size.width; x += 1) {
      final y =
          size.height * 0.8 +
          waveHeight *
              math.sin((x / waveLength * 2 * math.pi) + animationValue);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ParticlePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  ParticlePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final particleCount = 15;
    final random = math.Random(42); // Fixed seed for consistent particles

    for (int i = 0; i < particleCount; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;

      final x = baseX + math.sin(animationValue + i) * 20;
      final y = baseY + math.cos(animationValue + i * 0.8) * 15;

      final radius = 2 + math.sin(animationValue + i) * 1;

      if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
