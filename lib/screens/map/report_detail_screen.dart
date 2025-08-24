// lib/screens/map/report_detail_screen.dart - CORRECTED VERSION

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
import '../../widgets/common/custom_button.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

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

  // Animation controllers - Initialize immediately, not as late
  List<AnimationController>? _animationControllers;
  List<Animation<Offset>>? _slideAnimations;
  List<Animation<double>>? _scaleAnimations;

  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
  }

  void _initializeAnimations() {
    // Create multiple animation controllers for staggered effects
    _animationControllers = List.generate(
      8,
      (index) => AnimationController(
        duration: Duration(milliseconds: 600 + (index * 100)),
        vsync: this,
      ),
    );

    _slideAnimations = _animationControllers!
        .map(
          (controller) =>
              Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
              ),
        )
        .toList();

    _scaleAnimations = _animationControllers!
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.elasticOut),
          ),
        )
        .toList();

    // Mark animations as initialized
    _animationsInitialized = true;

    // Start animations with delays
    for (int i = 0; i < _animationControllers!.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _animationControllers![i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_animationControllers != null) {
      for (var controller in _animationControllers!) {
        controller.dispose();
      }
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
                Icon(Icons.location_off, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Current location not available'),
              ],
            ),
            backgroundColor: AppTheme.warningOrange,
            behavior: SnackBarBehavior.floating,
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
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Could not open maps'),
              ],
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return loading state if animations not initialized
    if (!_animationsInitialized ||
        _slideAnimations == null ||
        _scaleAnimations == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(title: const Text('Report Details'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Report Details'),
        elevation: 0,
        actions: [
          AnimatedBuilder(
            animation: _scaleAnimations![0],
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimations![0].value,
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Share functionality coming soon!'),
                        backgroundColor: AppTheme.infoBlue,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _slideAnimations![0],
        builder: (context, child) {
          return Transform.translate(
            offset: _slideAnimations![0].value * 50,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section
                  _buildImageSection(),
                  // Details Section
                  AnimatedBuilder(
                    animation: _slideAnimations![1],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _slideAnimations![1].value * 50,
                        child: _buildDetailsSection(),
                      );
                    },
                  ),
                  // Location Section with Directions
                  AnimatedBuilder(
                    animation: _slideAnimations![2],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _slideAnimations![2].value * 50,
                        child: _buildLocationSection(),
                      );
                    },
                  ),
                  // AI Analysis Section
                  if (widget.report.visionVerified)
                    AnimatedBuilder(
                      animation: _slideAnimations![3],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: _slideAnimations![3].value * 50,
                          child: _buildAIAnalysisSection(),
                        );
                      },
                    ),
                  // Safety Warnings
                  if (widget.report.safetyWarnings.isNotEmpty)
                    AnimatedBuilder(
                      animation: _slideAnimations![4],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: _slideAnimations![4].value * 50,
                          child: _buildSafetySection(),
                        );
                      },
                    ),
                  // Action Section
                  AnimatedBuilder(
                    animation: _slideAnimations![5],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _slideAnimations![5].value * 50,
                        child: _buildActionSection(),
                      );
                    },
                  ),
                  const SizedBox(height: 120), // Space for bottom button
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _slideAnimations![6],
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _slideAnimations![6].value.dy.abs()) * 100),
            child: _buildBottomActions(),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return Hero(
      tag: 'report_image_${widget.report.id}',
      child: Container(
        width: double.infinity,
        height: 300,
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: widget.report.imageURL,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.lightGreen.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.lightGreen.withOpacity(0.3),
                child: const Center(child: Icon(Icons.error, size: 50)),
              ),
            ),
            // Gradient overlay for better text visibility
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimations![1],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimations![1].value,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Helpers.getSeverityColor(
                            widget.report.severity,
                          ).withOpacity(0.1),
                        ),
                        child: Icon(
                          _getTrashTypeIcon(widget.report.trashType),
                          color: Helpers.getSeverityColor(
                            widget.report.severity,
                          ),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Helpers.getTrashTypeDisplayName(
                          widget.report.trashType,
                        ),
                        style: AppTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                widget.report.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusDisplayName(widget.report.status),
                              style: AppTheme.bodyMedium.copyWith(
                                color: _getStatusColor(widget.report.status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Helpers.getSeverityColor(
                                widget.report.severity,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.report.severity.toUpperCase()} SEVERITY',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Helpers.getSeverityColor(
                                  widget.report.severity,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
            const SizedBox(height: 20),
            // Detail rows with individual animations
            ..._buildDetailRows(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailRows() {
    final details = [
      {
        'icon': Icons.timer_outlined,
        'label': 'Estimated Effort',
        'value': widget.report.estimatedEffort,
      },
      {
        'icon': Icons.access_time,
        'label': 'Reported',
        'value': Helpers.formatDateTime(widget.report.timestamp),
      },
      if (_currentPosition != null)
        {
          'icon': Icons.location_on,
          'label': 'Distance',
          'value': Helpers.formatDistance(_getDistanceToReport()),
        },
      if (widget.report.visionVerified)
        {
          'icon': Icons.psychology,
          'label': 'AI Confidence',
          'value':
              '${(widget.report.visionConfidence * 100).toStringAsFixed(1)}%',
        },
    ];

    return details.asMap().entries.map((entry) {
      final index = entry.key;
      final detail = entry.value;
      return AnimatedBuilder(
        animation:
            _slideAnimations![Math.min(
              index + 2,
              _slideAnimations!.length - 1,
            )],
        builder: (context, child) {
          return Transform.translate(
            offset:
                _slideAnimations![Math.min(
                      index + 2,
                      _slideAnimations!.length - 1,
                    )]
                    .value *
                30,
            child: _buildDetailRow(
              detail['icon'] as IconData,
              detail['label'] as String,
              detail['value'] as String,
            ),
          );
        },
      );
    }).toList();
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const Spacer(),
          Text(value, style: AppTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimations![2],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimations![2].value,
                      child: Icon(
                        Icons.location_on,
                        color: AppTheme.primaryGreen,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text('Location', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.report.address, style: AppTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Coordinates: ${widget.report.location.latitude.toStringAsFixed(6)}, ${widget.report.location.longitude.toStringAsFixed(6)}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            // Directions Button with animation
            AnimatedBuilder(
              animation: _scaleAnimations![3],
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimations![3].value,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openGoogleMapsRoute,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Get Directions'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.primaryGreen),
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysisSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimations![3],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimations![3].value,
                      child: Icon(Icons.psychology, color: AppTheme.infoBlue),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text('AI Analysis', style: AppTheme.headlineMedium),
                const Spacer(),
                AnimatedBuilder(
                  animation: _scaleAnimations![4],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimations![4].value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'VERIFIED',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Confidence: ${(widget.report.visionConfidence * 100).toStringAsFixed(1)}%',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text('Detected Labels:', style: AppTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.report.visionLabels
                  .take(6)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final label = entry.value;
                    return AnimatedBuilder(
                      animation:
                          _scaleAnimations![Math.min(
                            index + 4,
                            _scaleAnimations!.length - 1,
                          )],
                      builder: (context, child) {
                        return Transform.scale(
                          scale:
                              _scaleAnimations![Math.min(
                                    index + 4,
                                    _scaleAnimations!.length - 1,
                                  )]
                                  .value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    );
                  })
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimations![4],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimations![4].value,
                      child: Icon(
                        Icons.warning_amber,
                        color: AppTheme.warningOrange,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Safety Warnings',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.warningOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.report.safetyWarnings.asMap().entries.map((entry) {
              final index = entry.key;
              final warning = entry.value;
              return AnimatedBuilder(
                animation:
                    _slideAnimations![Math.min(
                      index + 5,
                      _slideAnimations!.length - 1,
                    )],
                builder: (context, child) {
                  return Transform.translate(
                    offset:
                        _slideAnimations![Math.min(
                              index + 5,
                              _slideAnimations!.length - 1,
                            )]
                            .value *
                        20,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(warning, style: AppTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Community Action', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            if (widget.report.votes.upvotes > 0 ||
                widget.report.votes.downvotes > 0) ...[
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  Text('${widget.report.votes.upvotes}'),
                  const SizedBox(width: 16),
                  Icon(Icons.thumb_down, size: 16, color: AppTheme.dangerRed),
                  const SizedBox(width: 4),
                  Text('${widget.report.votes.downvotes}'),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Fixed Row for buttons - no StaggeredListAnimation wrapping Expanded widgets
            Row(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: _scaleAnimations![5],
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimations![5].value,
                        child: OutlinedButton.icon(
                          onPressed: () => _voteOnReport(true),
                          icon: const Icon(Icons.thumb_up, size: 16),
                          label: const Text('Helpful'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.primaryGreen),
                            foregroundColor: AppTheme.primaryGreen,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _scaleAnimations![6],
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimations![6].value,
                        child: OutlinedButton.icon(
                          onPressed: () => _voteOnReport(false),
                          icon: const Icon(Icons.thumb_down, size: 16),
                          label: const Text('Not Helpful'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.dangerRed),
                            foregroundColor: AppTheme.dangerRed,
                          ),
                        ),
                      );
                    },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canAcceptChallenge)
              AnimatedBuilder(
                animation: _scaleAnimations![6],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimations![6].value,
                    child: CustomButton(
                      text: 'Accept Cleanup Challenge',
                      icon: Icons.cleaning_services,
                      isLoading: _isAccepting,
                      onPressed: _acceptChallenge,
                    ),
                  );
                },
              ),
            if (canAcceptChallenge) const SizedBox(height: 12),
            // Always show directions button
            AnimatedBuilder(
              animation: _scaleAnimations![7],
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimations![7].value,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openGoogleMapsRoute,
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions in Maps'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: AppTheme.primaryGreen,
                          width: 2,
                        ),
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptChallenge() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() => _isAccepting = true);

    try {
      // Direct Firestore update
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
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Challenge accepted! Good luck with the cleanup.'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
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
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to accept challenge: $e'),
              ],
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
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
                Icon(Icons.thumb_up, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Thank you for your feedback!'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to submit vote: $e'),
              ],
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      case 'verified':
        return AppTheme.primaryGreen;
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
      case 'verified':
        return 'Available for Cleanup';
      case 'cleaning':
        return 'Cleanup in Progress';
      case 'completed':
        return 'Cleanup Completed';
      default:
        return status;
    }
  }
}
