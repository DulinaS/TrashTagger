// lib/screens/challenges/challenges_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/screens/map/report_detail_Screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_theme.dart';
import '../../models/trash_report_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class ChallengesScreen extends StatefulWidget {
  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TrashReportModel> _availableChallenges = [];
  List<TrashReportModel> _myChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /* Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      // Load available challenges (verified reports not yet accepted)
      final availableSnapshot = await FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', isEqualTo: 'verified')
          .where('acceptedBy', isNull: true)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _availableChallenges = availableSnapshot.docs
          .map((doc) => TrashReportModel.fromMap({'id': doc.id, ...doc.data()}))
          .where(
            (report) => report.reporterId != userId,
          ) // Don't show own reports
          .toList();

      // Load my accepted challenges
      if (userId != null) {
        final mySnapshot = await FirebaseFirestore.instance
            .collection('trashReports')
            .where('acceptedBy', isEqualTo: userId)
            .orderBy('acceptedAt', descending: true)
            .limit(20)
            .get();

        _myChallenges = mySnapshot.docs
            .map(
              (doc) => TrashReportModel.fromMap({'id': doc.id, ...doc.data()}),
            )
            .toList();
      }
    } catch (e) {
      print('Error loading challenges: $e');
    }

    setState(() => _isLoading = false);
  } */
  // In your _loadChallenges method, add null safety:
  Future<void> _loadChallenges() async {
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
                // Pass the actual Firestore document ID
                return TrashReportModel.fromMap({
                  '_documentId': doc.id, // Pass the real document ID
                  ...data,
                });
              }
              return null;
            } catch (e) {
              print('⚠️ Error parsing report ${doc.id}: $e');
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
                // Pass the actual Firestore document ID
                return TrashReportModel.fromMap({
                  '_documentId': doc.id, // Pass the real document ID
                  ...doc.data(),
                });
              } catch (e) {
                print('⚠️ Error parsing my challenge ${doc.id}: $e');
                return null;
              }
            })
            .where((report) => report != null)
            .cast<TrashReportModel>()
            .toList();
      }

      print(
        '✅ Loaded ${_availableChallenges.length} available, ${_myChallenges.length} my challenges',
      );
    } catch (e) {
      print('❌ Error loading challenges: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Cleanup Challenges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.search),
              text: 'Available (${_availableChallenges.length})',
            ),
            Tab(
              icon: const Icon(Icons.assignment),
              text: 'My Challenges (${_myChallenges.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChallenges,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading challenges...')
          : TabBarView(
              controller: _tabController,
              children: [_buildAvailableChallenges(), _buildMyChallenges()],
            ),
    );
  }

  Widget _buildAvailableChallenges() {
    if (_availableChallenges.isEmpty) {
      return EmptyStateWidget(
        title: 'No Challenges Available',
        message:
            'All reported trash has been claimed for cleanup!\nCheck back later for new reports.',
        icon: Icons.done_all,
        actionText: 'Report New Trash',
        onAction: () {
          // Navigate to camera tab
          DefaultTabController.of(context)?.animateTo(2);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _availableChallenges[index];
          return _buildChallengeCard(challenge, isAvailable: true);
        },
      ),
    );
  }

  Widget _buildMyChallenges() {
    if (_myChallenges.isEmpty) {
      return EmptyStateWidget(
        title: 'No Active Challenges',
        message:
            'You haven\'t accepted any cleanup challenges yet.\nStart making a difference!',
        icon: Icons.cleaning_services,
        actionText: 'Find Challenges',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _myChallenges[index];
          return _buildChallengeCard(challenge, isAvailable: false);
        },
      ),
    );
  }

  Widget _buildChallengeCard(
    TrashReportModel challenge, {
    required bool isAvailable,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToChallengeDetail(challenge),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Challenge Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Helpers.getSeverityColor(
                        challenge.severity,
                      ).withOpacity(0.1),
                    ),
                    child: Icon(
                      _getTrashTypeIcon(challenge.trashType),
                      color: Helpers.getSeverityColor(challenge.severity),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Challenge Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Helpers.getTrashTypeDisplayName(challenge.trashType),
                          style: AppTheme.headlineMedium.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Helpers.getSeverityColor(
                                  challenge.severity,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${challenge.severity.toUpperCase()} PRIORITY',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 11,
                                  color: Helpers.getSeverityColor(
                                    challenge.severity,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isAvailable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    challenge.status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusDisplayName(challenge.status),
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontSize: 11,
                                    color: _getStatusColor(challenge.status),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Points Reward
                  Column(
                    children: [
                      Text(
                        '${_getRewardPoints(challenge.severity)}',
                        style: AppTheme.headlineMedium.copyWith(
                          color: AppTheme.primaryGreen,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'points',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Location
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      challenge.address,
                      style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Time and Effort
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Helpers.formatDateTime(challenge.timestamp),
                    style: AppTheme.bodyMedium.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    challenge.estimatedEffort,
                    style: AppTheme.bodyMedium.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),

              // Safety Warnings
              if (challenge.safetyWarnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.warningOrange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          challenge.safetyWarnings.first,
                          style: AppTheme.bodyMedium.copyWith(
                            fontSize: 12,
                            color: AppTheme.warningOrange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              if (isAvailable) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _navigateToChallengeDetail(challenge),
                        child: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptChallenge(challenge),
                        child: const Text('Accept Challenge'),
                      ),
                    ),
                  ],
                ),
              ] else if (challenge.status == 'cleaning') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _submitProof(challenge),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Submit Cleanup Proof'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.infoBlue,
                    ),
                  ),
                ),
              ],
            ],
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

  /* Future<void> _acceptChallenge(TrashReportModel challenge) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(
      context,
      listen: false,
    );

    if (authProvider.user == null) return;

    try {
      await reportsProvider.acceptChallenge(
        challenge.id,
        authProvider.user!.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge accepted! Good luck with the cleanup.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );

      // Refresh the lists
      _loadChallenges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept challenge: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  } */
  Future<void> _acceptChallenge(TrashReportModel challenge) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    try {
      print('🎯 Accepting challenge: ${challenge.id}');

      // Use UPDATE instead of SET to modify existing document
      await FirebaseFirestore.instance
          .collection('trashReports')
          .doc(challenge.id)
          .update({
            'acceptedBy': authProvider.user!.uid,
            'acceptedAt': FieldValue.serverTimestamp(),
            'status': 'cleaning',
          });

      print('✅ Challenge accepted - document updated');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge accepted! Good luck with the cleanup.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );

      // Reload challenges to update UI
      setState(() {
        _isLoading = true;
      });
      await _loadChallenges();
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting challenge: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _submitProof(TrashReportModel challenge) async {
    // TODO: Implement camera capture for cleanup proof
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleanup proof submission - Coming soon!'),
        backgroundColor: AppTheme.infoBlue,
      ),
    );
  }

  IconData _getTrashTypeIcon(String trashType) {
    switch (trashType) {
      case 'general':
        return Icons.delete_outline;
      case 'recyclable':
        return Icons.recycling;
      case 'hazardous':
        return Icons.warning;
      case 'large':
        return Icons.chair;
      case 'organic':
        return Icons.eco;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'cleaning':
        return AppTheme.infoBlue;
      case 'completed':
        return AppTheme.primaryGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'cleaning':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
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
