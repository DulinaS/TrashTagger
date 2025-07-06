// lib/screens/map/report_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/trash_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/custom_button.dart';

class ReportDetailScreen extends StatefulWidget {
  final TrashReportModel report;

  const ReportDetailScreen({Key? key, required this.report}) : super(key: key);

  @override
  _ReportDetailScreenState createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Report Details'), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            _buildImageSection(),

            // Details Section
            _buildDetailsSection(),

            // Location Section
            _buildLocationSection(),

            // AI Analysis Section
            if (widget.report.visionVerified) _buildAIAnalysisSection(),

            // Safety Warnings
            if (widget.report.safetyWarnings.isNotEmpty) _buildSafetySection(),

            // Action Section
            _buildActionSection(),

            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      height: 300,
      child: CachedNetworkImage(
        imageUrl: widget.report.imageURL,
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
                Container(
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
                    color: Helpers.getSeverityColor(widget.report.severity),
                    size: 24,
                  ),
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

            // Effort Estimate
            _buildDetailRow(
              Icons.timer_outlined,
              'Estimated Effort',
              widget.report.estimatedEffort,
            ),

            // Report Time
            _buildDetailRow(
              Icons.access_time,
              'Reported',
              Helpers.formatDateTime(widget.report.timestamp),
            ),

            // AI Confidence
            if (widget.report.visionVerified)
              _buildDetailRow(
                Icons.psychology,
                'AI Confidence',
                '${(widget.report.visionConfidence * 100).toStringAsFixed(1)}%',
              ),
          ],
        ),
      ),
    );
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
                Icon(Icons.location_on, color: AppTheme.primaryGreen),
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
                Icon(Icons.psychology, color: AppTheme.infoBlue),
                const SizedBox(width: 8),
                Text('AI Analysis', style: AppTheme.headlineMedium),
                const Spacer(),
                Container(
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
              children: widget.report.visionLabels.take(6).map((label) {
                return Container(
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
                );
              }).toList(),
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
                Icon(Icons.warning_amber, color: AppTheme.warningOrange),
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
            ...widget.report.safetyWarnings.map((warning) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppTheme.warningOrange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(warning, style: AppTheme.bodyMedium)),
                  ],
                ),
              );
            }),
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _voteOnReport(true),
                    icon: const Icon(Icons.thumb_up, size: 16),
                    label: const Text('Helpful'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _voteOnReport(false),
                    icon: const Icon(Icons.thumb_down, size: 16),
                    label: const Text('Not Helpful'),
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

    if (!canAcceptChallenge) return const SizedBox.shrink();

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
        child: CustomButton(
          text: 'Accept Cleanup Challenge',
          icon: Icons.cleaning_services,
          isLoading: _isAccepting,
          onPressed: _acceptChallenge,
        ),
      ),
    );
  }

  /* Future<void> _acceptChallenge() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(
      context,
      listen: false,
    );

    if (authProvider.user == null) return;

    setState(() => _isAccepting = true);

    try {
      await reportsProvider.acceptChallenge(
        widget.report.id,
        authProvider.user!.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge accepted! Good luck with the cleanup.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept challenge: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }

    setState(() => _isAccepting = false);
  } */
  // In your ReportDetailScreen, replace the _acceptChallenge method:
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
            content: Text('Challenge accepted! Good luck with the cleanup.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error accepting challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept challenge: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }

    setState(() => _isAccepting = false);
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
            content: Text('Thank you for your feedback!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit vote: $e'),
            backgroundColor: AppTheme.dangerRed,
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
