// lib/screens/challenges/challenges_screen.dart - Fixed with Proper UI Pattern
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/screens/challenges/cleanup_proof_screen.dart';
import 'package:trash_tagger/screens/map/report_detail_Screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_theme.dart';
import '../../models/trash_report_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class ChallengesScreen extends StatefulWidget {
  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _refreshController;

  List<TrashReportModel> _availableChallenges = [];
  List<TrashReportModel> _myChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  /* Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      // Load available challenges
      final availableSnapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', isEqualTo: 'verified')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _availableChallenges = availableSnapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              if (data['acceptedBy'] == null && data['reporterId'] != userId) {
                return TrashReportModel.fromMap({
                  '_documentId': doc.id,
                  ...data,
                });
              }
              return null;
            } catch (e) {
              print('Error parsing report ${doc.id}: $e');
              return null;
            }
          })
          .where((report) => report != null)
          .cast<TrashReportModel>()
          .toList();

      // Load my challenges
      if (userId != null) {
        final mySnapshot = await FirebaseFirestore.instance
            .collection('trashReports')
            .where('acceptedBy', isEqualTo: userId)
            .orderBy('acceptedAt', descending: true)
            .limit(20)
            .get();

        _myChallenges = mySnapshot.docs
            .map((doc) {
              try {
                return TrashReportModel.fromMap({
                  '_documentId': doc.id,
                  ...doc.data(),
                });
              } catch (e) {
                print('Error parsing my challenge ${doc.id}: $e');
                return null;
              }
            })
            .where((report) => report != null)
            .cast<TrashReportModel>()
            .toList();
      }

      print(
        'Loaded ${_availableChallenges.length} available, ${_myChallenges.length} my challenges',
      );
    } catch (e) {
      print('Error loading challenges: $e');
    }

    setState(() => _isLoading = false);
  }
 */

  Future<void> _loadChallenges() async {
    if (!mounted) return; // Check if widget is still mounted

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      // Load available challenges
      final availableSnapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', isEqualTo: 'verified')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (!mounted) return; // Check again after async operation

      _availableChallenges = availableSnapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              if (data['acceptedBy'] == null && data['reporterId'] != userId) {
                return TrashReportModel.fromMap({
                  '_documentId': doc.id,
                  ...data,
                });
              }
              return null;
            } catch (e) {
              print('Error parsing report ${doc.id}: $e');
              return null;
            }
          })
          .where((report) => report != null)
          .cast<TrashReportModel>()
          .toList();

      // Load my challenges
      if (userId != null) {
        final mySnapshot = await FirebaseFirestore.instance
            .collection('trashReports')
            .where('acceptedBy', isEqualTo: userId)
            .orderBy('acceptedAt', descending: true)
            .limit(20)
            .get();

        if (!mounted) return; // Check again after second async operation

        _myChallenges = mySnapshot.docs
            .map((doc) {
              try {
                return TrashReportModel.fromMap({
                  '_documentId': doc.id,
                  ...doc.data(),
                });
              } catch (e) {
                print('Error parsing my challenge ${doc.id}: $e');
                return null;
              }
            })
            .where((report) => report != null)
            .cast<TrashReportModel>()
            .toList();
      }

      print(
        'Loaded ${_availableChallenges.length} available, ${_myChallenges.length} my challenges',
      );
    } catch (e) {
      print('Error loading challenges: $e');
    }

    // Final mounted check before setState
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshChallenges() async {
    _refreshController.forward().then((_) {
      _refreshController.reset();
    });
    await _loadChallenges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: Column(
          children: [
            // Stats Header
            SlideInAnimation(
              delay: AnimationConstants.shortDelay,
              child: _buildStatsHeader(),
            ),

            // Animated Tab Bar
            SlideInAnimation(
              delay: AnimationConstants.mediumDelay,
              child: _buildAnimatedTabBar(),
            ),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const LoadingWidget(message: 'Loading challenges...')
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAvailableChallenges(),
                        _buildMyChallenges(),
                      ],
                    ),
            ),
          ],
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
                AppTheme.primaryEmerald.withOpacity(0.1),
                AppTheme.accentPurple.withOpacity(0.05),
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
                  colors: [AppTheme.accentPurple, AppTheme.primaryTeal],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cleaning_services_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cleanup Challenges',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: IconButton(
            onPressed: _refreshChallenges,
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
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryEmerald,
        unselectedLabelColor: AppTheme.textTertiary,
        labelStyle: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTheme.labelMedium,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppTheme.primaryGradient.scale(0.1),
        ),
        indicatorPadding: const EdgeInsets.all(2),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Container(
            height: 48, // Set fixed height for proper coverage
            child: Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_rounded, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Available (${_availableChallenges.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48, // Set fixed height for proper coverage
            child: Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_rounded, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'My Challenges (${_myChallenges.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryEmerald.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Available',
              _availableChallenges.length.toString(),
              Icons.eco_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _buildStatItem(
              'In Progress',
              _myChallenges
                  .where((c) => c.status == 'cleaning')
                  .length
                  .toString(),
              Icons.cleaning_services_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _buildStatItem(
              'Completed',
              _myChallenges
                  .where((c) => c.status == 'completed')
                  .length
                  .toString(),
              Icons.check_circle_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTheme.headlineMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableChallenges() {
    if (_availableChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.done_all_rounded,
        title: 'No Challenges Available',
        message:
            'All reported trash has been claimed for cleanup!\nCheck back later for new reports.',
        actionText: 'Report New Trash',
        onAction: () {
          DefaultTabController.of(context)?.animateTo(2);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _availableChallenges.length,
        itemBuilder: (context, index) {
          return SlideInAnimation(
            delay: Duration(milliseconds: index * 50),
            child: _buildModernChallengeCard(
              _availableChallenges[index],
              isAvailable: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyChallenges() {
    if (_myChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cleaning_services_rounded,
        title: 'No Active Challenges',
        message:
            'You haven\'t accepted any cleanup challenges yet.\nStart making a difference!',
        actionText: 'Find Challenges',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _myChallenges.length,
        itemBuilder: (context, index) {
          return SlideInAnimation(
            delay: Duration(milliseconds: index * 50),
            child: _buildModernChallengeCard(
              _myChallenges[index],
              isAvailable: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryEmerald.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                actionText,
                style: AppTheme.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernChallengeCard(
    TrashReportModel challenge, {
    required bool isAvailable,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToChallengeDetail(challenge),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppTheme.getSeverityGradient(
                          challenge.severity,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.getSeverityColor(
                              challenge.severity,
                            ).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getTrashTypeIcon(challenge.trashType),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Helpers.getTrashTypeDisplayName(
                              challenge.trashType,
                            ),
                            style: AppTheme.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.getSeverityColor(
                                    challenge.severity,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${challenge.severity.toUpperCase()} PRIORITY',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.getSeverityColor(
                                      challenge.severity,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!isAvailable)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      challenge.status,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getStatusDisplayName(challenge.status),
                                    style: AppTheme.labelSmall.copyWith(
                                      color: _getStatusColor(challenge.status),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Points Reward
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.warningGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentAmber.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_getRewardPoints(challenge.severity)}',
                            style: AppTheme.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'points',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Location and Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppTheme.primaryEmerald,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              challenge.address,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Helpers.formatDateTime(challenge.timestamp),
                            style: AppTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              challenge.estimatedEffort,
                              style: AppTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Safety Warnings
                if (challenge.safetyWarnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningAmber.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: AppTheme.warningAmber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            challenge.safetyWarnings.first,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.warningAmber,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                const SizedBox(height: 20),
                if (isAvailable)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _navigateToChallengeDetail(challenge),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.primaryEmerald),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppTheme.primaryEmerald,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'View Details',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: AppTheme.primaryEmerald,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryEmerald.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _acceptChallenge(challenge),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.volunteer_activism_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Accept Challenge',
                                        style: AppTheme.labelMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (challenge.status == 'cleaning' ||
                    challenge.status == 'disputed')
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: challenge.status == 'disputed'
                          ? AppTheme.warningGradient
                          : LinearGradient(
                              colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (challenge.status == 'disputed'
                                      ? AppTheme.warningAmber
                                      : AppTheme.infoBlue)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _submitProof(challenge),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  challenge.status == 'disputed'
                                      ? 'Resubmit Cleanup Proof'
                                      : 'Submit Cleanup Proof',
                                  style: AppTheme.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChallengeDetail(TrashReportModel challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(report: challenge),
      ),
    );
  }

  Future<void> _acceptChallenge(TrashReportModel challenge) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    try {
      print('Accepting challenge: ${challenge.id}');

      await FirebaseFirestore.instance
          .collection('trashReports')
          .doc(challenge.id)
          .update({
            'acceptedBy': authProvider.user!.uid,
            'acceptedAt': FieldValue.serverTimestamp(),
            'status': 'cleaning',
          });

      print('Challenge accepted - document updated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Challenge accepted! Good luck with the cleanup.'),
              ],
            ),
            backgroundColor: AppTheme.primaryEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      setState(() {
        _isLoading = true;
      });
      await _loadChallenges();
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error accepting challenge: $e'),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _submitProof(TrashReportModel challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CleanupProofScreen(challenge: challenge),
      ),
    );
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

  Color _getStatusColor(String status) {
    return AppTheme.getStatusColor(status);
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'cleaning':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'disputed':
        return 'DISPUTED';
      default:
        return status.toUpperCase();
    }
  }

  int _getRewardPoints(String severity) {
    switch (severity) {
      case 'low':
        return 20;
      case 'medium':
        return 30;
      case 'high':
        return 50;
      default:
        return 20;
    }
  }
}
