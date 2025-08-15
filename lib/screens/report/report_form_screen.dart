import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/screens/location/location_picker_screen.dart'; // Fixed import path
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/storage_service.dart';
import '../../models/trash_report_model.dart';
import '../../themes/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/custom_button.dart';
import 'report_success_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final File imageFile;

  const ReportFormScreen({Key? key, required this.imageFile}) : super(key: key);

  @override
  _ReportFormScreenState createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Location selection variables
  LatLng? _selectedLocation;
  String _selectedAddress = '';

  // Form variables
  String _selectedTrashType = 'general';
  String _selectedSeverity = 'low';
  bool _isSubmitting = false;
  String? _error;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _clearError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Report Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Section
            _buildImagePreview(),
            const SizedBox(height: 24),

            // Location Selection Section
            _buildLocationSection(),
            const SizedBox(height: 24),

            // Trash Type Selection
            _buildTrashTypeSection(),
            const SizedBox(height: 24),

            // Severity Selection
            _buildSeveritySection(),
            const SizedBox(height: 24),

            // Description Section
            _buildDescriptionSection(),
            const SizedBox(height: 24),

            // Estimated Effort Display
            _buildEffortEstimateSection(),
            const SizedBox(height: 24),

            // Safety Notice
            _buildSafetyNotice(),

            // Error Display
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorDisplay(),
            ],

            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text('Photo Preview', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                widget.imageFile,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology, size: 16, color: AppTheme.infoBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This photo will be analyzed by AI for verification',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.infoBlue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text('Location', style: AppTheme.headlineMedium),
                const Spacer(),
                if (_selectedLocation == null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'REQUIRED',
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 10,
                        color: AppTheme.warningOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Selected location display
            if (_selectedLocation != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Location Selected',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_selectedAddress, style: AppTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                      'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Select location button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectLocationOnMap,
                icon: Icon(
                  _selectedLocation == null ? Icons.map : Icons.edit_location,
                ),
                label: Text(
                  _selectedLocation == null
                      ? 'Select Location on Map'
                      : 'Change Location',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedLocation == null
                      ? AppTheme.primaryGreen
                      : AppTheme.infoBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            if (_selectedLocation == null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please select the exact location where you found the trash',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.warningOrange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrashTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text('Trash Type', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.trashTypes.map((type) {
                final isSelected = _selectedTrashType == type;
                return FilterChip(
                  avatar: Icon(
                    _getTrashTypeIcon(type),
                    size: 18,
                    color: isSelected ? Colors.white : AppTheme.primaryGreen,
                  ),
                  label: Text(Helpers.getTrashTypeDisplayName(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTrashType = type;
                      _clearError();
                    });
                  },
                  selectedColor: AppTheme.primaryGreen,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primaryGreen,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _buildTrashTypeDescription(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrashTypeDescription() {
    final descriptions = {
      'general': 'Common waste like food wrappers, papers, bottles, etc.',
      'recyclable': 'Plastic bottles, cans, cardboard that can be recycled',
      'hazardous':
          'Chemicals, batteries, medical waste - requires special handling',
      'large': 'Furniture, appliances, large items that need special pickup',
      'organic': 'Food waste, leaves, compostable materials',
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        descriptions[_selectedTrashType] ?? '',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSeveritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text('Severity Level', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: AppConstants.severityLevels.map((severity) {
                final isSelected = _selectedSeverity == severity;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Helpers.getSeverityColor(severity)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      _getSeverityDisplayName(severity),
                      style: AppTheme.labelMedium.copyWith(
                        color: isSelected
                            ? Helpers.getSeverityColor(severity)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _getSeverityDescription(severity),
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                    value: severity,
                    groupValue: _selectedSeverity,
                    onChanged: (value) {
                      setState(() {
                        _selectedSeverity = value!;
                        _clearError();
                      });
                    },
                    activeColor: Helpers.getSeverityColor(severity),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text('Additional Details', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText:
                    'Any additional information about this trash...\n'
                    'e.g., "Behind the bus stop", "Near the playground"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '${_descriptionController.text.length}/200',
              ),
              onChanged: (value) {
                setState(() {}); // Update counter
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffortEstimateSection() {
    final effort = _getEstimatedEffort(_selectedSeverity);
    final points = _getExpectedPoints(_selectedSeverity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text('Cleanup Estimate', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.timer, color: AppTheme.infoBlue),
                        const SizedBox(height: 4),
                        Text(
                          effort,
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.infoBlue,
                          ),
                        ),
                        Text(
                          'Estimated Time',
                          style: AppTheme.bodyMedium.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.stars, color: AppTheme.primaryGreen),
                        const SizedBox(height: 4),
                        Text(
                          '$points pts',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        Text(
                          'Cleanup Reward',
                          style: AppTheme.bodyMedium.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyNotice() {
    bool showHazardWarning = _selectedTrashType == 'hazardous';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: showHazardWarning
            ? AppTheme.dangerRed.withOpacity(0.1)
            : AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: showHazardWarning
              ? AppTheme.dangerRed.withOpacity(0.3)
              : AppTheme.warningOrange.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                showHazardWarning ? Icons.dangerous : Icons.warning_amber,
                color: showHazardWarning
                    ? AppTheme.dangerRed
                    : AppTheme.warningOrange,
              ),
              const SizedBox(width: 8),
              Text(
                showHazardWarning
                    ? 'Hazardous Material Warning'
                    : 'Safety Notice',
                style: AppTheme.labelMedium.copyWith(
                  color: showHazardWarning
                      ? AppTheme.dangerRed
                      : AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            showHazardWarning
                ? 'DANGER: Hazardous materials require special handling. Do NOT attempt to clean these yourself. Contact local authorities or hazmat disposal services immediately.'
                : 'If you see hazardous materials (chemicals, needles, medical waste, etc.), do not attempt to clean them yourself. Report them and let professionals handle the cleanup.',
            style: AppTheme.bodyMedium,
          ),
          if (showHazardWarning) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ This report will be flagged for professional cleanup only.',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.dangerRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.dangerRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
          text: _isSubmitting ? 'Submitting Report...' : 'Submit Report',
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitReport,
          icon: Icons.send,
        ),
      ),
    );
  }

  // Location selection method
  Future<void> _selectLocationOnMap() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLocation: _selectedLocation,
            initialAddress: _selectedAddress,
            title: 'Where did you find this trash?',
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _selectedLocation = result['location'] as LatLng;
          _selectedAddress = result['address'] as String;
          _clearError();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to open location picker: ${e.toString()}';
        });
      }
    }
  }

  // Submit report method
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate location selection
    if (_selectedLocation == null) {
      setState(() {
        _error =
            'Please select a location on the map where you found the trash';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final reportsProvider = Provider.of<ReportsProvider>(
        context,
        listen: false,
      );

      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      // Upload image to Firebase Storage
      final imageUrl = await _storageService.uploadTrashReportImage(
        widget.imageFile,
        authProvider.user!.uid,
      );

      // Create report model with Google Maps location
      final report = TrashReportModel(
        id: const Uuid().v4(),
        imageURL: imageUrl,
        location: GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        address: _selectedAddress,
        reporterId: authProvider.user!.uid,
        timestamp: DateTime.now(),
        status: 'pending',
        visionVerified: false,
        visionLabels: [],
        visionConfidence: 0.0,
        moderatorReviewed: false,
        trashType: _selectedTrashType,
        severity: _selectedSeverity,
        safetyWarnings: _selectedTrashType == 'hazardous'
            ? ['⚠️ Hazardous materials - contact authorities']
            : [],
        estimatedEffort: _getEstimatedEffort(_selectedSeverity),
        votes: ReportVotes(upvotes: 0, downvotes: 0, voters: []),
        flagged: false,
        flagReasons: [],
      );

      // Add additional metadata for enhanced verification
      final reportData = report.toMap();
      reportData['reportMetadata'] = {
        'locationSource': 'google_maps',
        'locationAccuracy': 'precise',
        'submissionMethod': 'mobile_app',
        'appVersion': '2.0.0',
        'description': _descriptionController.text.trim(),
      };

      // Submit to Firestore (triggers Cloud Function AI analysis)
      final reportId = await reportsProvider.createReport(report);

      // Navigate to success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportSuccessScreen(reportId: reportId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit report: ${e.toString()}';
          _isSubmitting = false;
        });
      }
    }
  }

  // Helper methods
  void _clearError() {
    if (_error != null) {
      setState(() {
        _error = null;
      });
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Report Trash'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📍 Location Selection'),
              Text('• Select the exact location where you found the trash'),
              Text('• Use the search or pin placement on the map'),
              Text('• Be as precise as possible for accurate cleanup'),
              SizedBox(height: 12),

              Text('🗑️ Trash Type'),
              Text('• Choose the category that best describes the waste'),
              Text('• Select "Hazardous" for dangerous materials'),
              Text('• When in doubt, choose "General"'),
              SizedBox(height: 12),

              Text('⚡ Severity Level'),
              Text('• Low: Small amount, quick cleanup'),
              Text('• Medium: Moderate effort required'),
              Text('• High: Large amount or difficult cleanup'),
              SizedBox(height: 12),

              Text('📋 What Happens Next'),
              Text('• AI analyzes your photo for verification'),
              Text('• Report becomes available as a cleanup challenge'),
              Text('• Community members can accept and complete it'),
              Text('• You earn points when it\'s successfully cleaned!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
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

  String _getSeverityDisplayName(String severity) {
    switch (severity) {
      case 'low':
        return 'Low Priority';
      case 'medium':
        return 'Medium Priority';
      case 'high':
        return 'High Priority';
      default:
        return severity;
    }
  }

  String _getSeverityDescription(String severity) {
    switch (severity) {
      case 'low':
        return 'Small amount, easy to clean (5-15 min)';
      case 'medium':
        return 'Moderate amount, requires some effort (15-30 min)';
      case 'high':
        return 'Large amount or difficult to clean (30+ min)';
      default:
        return '';
    }
  }

  String _getEstimatedEffort(String severity) {
    switch (severity) {
      case 'low':
        return '5-15min';
      case 'medium':
        return '15-30min';
      case 'high':
        return '30min+';
      default:
        return '15min';
    }
  }

  int _getExpectedPoints(String severity) {
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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
