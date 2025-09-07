// lib/screens/map/report_detail_screen.dart - Modern Vibrant Design
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as Math;

import '../../models/trash_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/page_transitions.dart';

class ReportDetailScreen extends StatefulWidget {
  final TrashReportModel report;

  const ReportDetailScreen({Key? key, required this.report}) : super(key: key);

  @override
  _ReportDetailScreenState createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with TickerProviderStateMixin {
  bool _isAccepting = false;
  Position? _currentPosition;

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _contentController;
  late AnimationController _fabController;
  late List<AnimationController> _staggeredControllers;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
  }

  void _initializeAnimations() {
    _headerController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _contentController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );
    _fabController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    // Create staggered controllers for different sections
    _staggeredControllers = List.generate(
      6,
      (index) => AnimationController(
        duration: Duration(milliseconds: 400 + (index * 100)),
        vsync: this,
      ),
    );

    // Start animations with delays
    Future.delayed(AnimationConstants.microDelay, () {
      if (mounted) _headerController.forward();
    });

    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) _contentController.forward();
    });

    Future.delayed(AnimationConstants.extraLongDelay, () {
      if (mounted) _fabController.forward();
    });

    // Start staggered animations
    for (int i = 0; i < _staggeredControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 150)), () {
        if (mounted) _staggeredControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    _fabController.dispose();
    for (var controller in _staggeredControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _openGoogleMapsRoute() async {
    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Current location not available'),
              ],
            ),
            backgroundColor: AppTheme.warningAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    try {
      await MapsLauncher.launchCoordinates(
        widget.report.location.latitude,
        widget.report.location.longitude,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Could not open maps'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header Image Section
              SlideInAnimation(
                delay: AnimationConstants.microDelay,
                child: _buildImageSection(),
              ),

              // Details Section
              SlideInAnimation(
                delay: AnimationConstants.shortDelay,
                child: _buildDetailsSection(),
              ),

              // Location Section
              SlideInAnimation(
                delay: AnimationConstants.mediumDelay,
                child: _buildLocationSection(),
              ),

              // AI Analysis Section
              if (widget.report.visionVerified)
                SlideInAnimation(
                  delay: AnimationConstants.longDelay,
                  child: _buildAIAnalysisSection(),
                ),

              // Safety Warnings
              if (widget.report.safetyWarnings.isNotEmpty)
                SlideInAnimation(
                  delay: AnimationConstants.extraLongDelay,
                  child: _buildSafetySection(),
                ),

              // Action Section
              ScaleInAnimation(
                delay: const Duration(milliseconds: 600),
                child: _buildActionSection(),
              ),

              const SizedBox(height: 120), // Space for bottom button
            ],
          ),
        ),
      ),
      bottomNavigationBar: SlideInAnimation(
        beginOffset: AnimationConstants.slideFromBottom,
        delay: const Duration(milliseconds: 700),
        child: _buildBottomActions(),
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
                  colors: [AppTheme.primaryTeal, AppTheme.accentPurple],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Report Details',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: ScaleInAnimation(
            delay: AnimationConstants.mediumDelay,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: IconButton(
                icon: Icon(Icons.share_rounded, color: AppTheme.textPrimary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.info_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          const Text('Share functionality coming soon!'),
                        ],
                      ),
                      backgroundColor: AppTheme.infoBlue,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Hero(
        tag: 'report_image_${widget.report.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: widget.report.imageURL,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                placeholder: (context, url) => ShimmerAnimation(
                  child: Container(
                    height: 300,
                    color: AppTheme.backgroundPrimary,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          size: 60,
                          color: AppTheme.errorRed,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load image',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Status overlay
              Positioned(
                top: 16,
                right: 16,
                child: ModernStatusBadge(
                  status: widget.report.status,
                  showPulse: widget.report.status == 'cleaning',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppTheme.getSeverityGradient(
                      widget.report.severity,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.getSeverityColor(
                          widget.report.severity,
                        ).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getTrashTypeIcon(widget.report.trashType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Helpers.getTrashTypeDisplayName(
                          widget.report.trashType,
                        ),
                        style: AppTheme.headlineMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.getSeverityColor(
                                widget.report.severity,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.report.severity.toUpperCase()} PRIORITY',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.getSeverityColor(
                                  widget.report.severity,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Detail rows
            _buildDetailRow(
              Icons.timer_outlined,
              'Estimated Effort',
              widget.report.estimatedEffort,
              AppTheme.primaryEmerald,
            ),
            _buildDetailRow(
              Icons.access_time_rounded,
              'Reported',
              Helpers.formatDateTime(widget.report.timestamp),
              AppTheme.infoBlue,
            ),
            if (_currentPosition != null)
              _buildDetailRow(
                Icons.location_on_rounded,
                'Distance',
                Helpers.formatDistance(_getDistanceToReport()),
                AppTheme.primaryTeal,
              ),
            if (widget.report.visionVerified)
              _buildDetailRow(
                Icons.psychology_rounded,
                'AI Confidence',
                '${(widget.report.visionConfidence * 100).toStringAsFixed(1)}%',
                AppTheme.accentPurple,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryEmerald, AppTheme.primaryTeal],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Location',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                        Icons.place_rounded,
                        size: 16,
                        color: AppTheme.primaryEmerald,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.report.address,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coordinates: ${widget.report.location.latitude.toStringAsFixed(6)}, ${widget.report.location.longitude.toStringAsFixed(6)}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ModernGradientButton(
              text: 'Get Directions',
              onPressed: _openGoogleMapsRoute,
              icon: Icons.directions_rounded,
              isOutlined: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysisSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentCoral],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Analysis',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VERIFIED',
                    style: AppTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                      Text('Confidence: ', style: AppTheme.bodyMedium),
                      Text(
                        '${(widget.report.visionConfidence * 100).toStringAsFixed(1)}%',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detected Labels:',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.report.visionLabels.take(6).map((label) {
                      return ModernChip(
                        label: label,
                        selected: false,
                        selectedColor: AppTheme.accentPurple,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        backgroundColor: AppTheme.warningAmber.withOpacity(0.05),
        border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PulseAnimation(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Safety Warnings',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ...widget.report.safetyWarnings.map((warning) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 8,
                      color: AppTheme.warningAmber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        warning,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ModernCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentAmber, AppTheme.warningAmber],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.how_to_vote_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Community Feedback',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (widget.report.votes.upvotes > 0 ||
                widget.report.votes.downvotes > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.thumb_up_rounded,
                            size: 20,
                            color: AppTheme.successGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.report.votes.upvotes}',
                            style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Helpful',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.borderLight,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Not Helpful',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.errorRed,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.report.votes.downvotes}',
                            style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.errorRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.thumb_down_rounded,
                            size: 20,
                            color: AppTheme.errorRed,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              children: [
                Expanded(
                  child: ModernGradientButton(
                    text: 'Helpful',
                    onPressed: () => _voteOnReport(true),
                    icon: Icons.thumb_up_rounded,
                    gradient: AppTheme.successGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernGradientButton(
                    text: 'Not Helpful',
                    onPressed: () => _voteOnReport(false),
                    icon: Icons.thumb_down_rounded,
                    gradient: AppTheme.errorGradient,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final authProvider = Provider.of<AuthProvider>(context);
    final canAcceptChallenge =
        widget.report.status == 'verified' &&
        widget.report.acceptedBy == null &&
        widget.report.reporterId != authProvider.user?.uid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canAcceptChallenge) ...[
              ModernGradientButton(
                text: 'Accept Cleanup Challenge',
                icon: Icons.volunteer_activism_rounded,
                isLoading: _isAccepting,
                onPressed: _acceptChallenge,
                gradient: AppTheme.primaryGradient,
                width: double.infinity,
              ),
              const SizedBox(height: 12),
            ],
            ModernGradientButton(
              text: 'Get Directions in Maps',
              onPressed: _openGoogleMapsRoute,
              icon: Icons.directions_rounded,
              isOutlined: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  double _getDistanceToReport() {
    if (_currentPosition == null) return 0;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          widget.report.location.latitude,
          widget.report.location.longitude,
        ) /
        1000;
  }

  Future<void> _acceptChallenge() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() => _isAccepting = true);

    try {
      await FirebaseFirestore.instance
          .collection('trashReports')
          .doc(widget.report.id)
          .update({
            'acceptedBy': authProvider.user!.uid,
            'acceptedAt': FieldValue.serverTimestamp(),
            'status': 'cleaning',
          });

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
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error accepting challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Failed to accept challenge: $e'),
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

    if (mounted) {
      setState(() => _isAccepting = false);
    }
  }

  Future<void> _voteOnReport(bool isUpvote) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(
      context,
      listen: false,
    );
    if (authProvider.user == null) return;

    try {
      await reportsProvider.voteOnReport(
        widget.report.id,
        authProvider.user!.uid,
        isUpvote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isUpvote ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                const Text('Thank you for your feedback!'),
              ],
            ),
            backgroundColor: isUpvote
                ? AppTheme.successGreen
                : AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Failed to submit vote: $e'),
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
        return Icons.help_outline_rounded;
    }
  }
}
