// lib/screens/report/report_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final Position? location;
  final String? address;

  const ReportFormScreen({
    Key? key,
    required this.imageFile,
    this.location,
    this.address,
  }) : super(key: key);

  @override
  _ReportFormScreenState createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedTrashType = 'general';
  String _selectedSeverity = 'low';
  bool _isSubmitting = false;
  String? _error;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.address ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Report Details'), elevation: 0),
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
            // Image Preview
            _buildImagePreview(),
            const SizedBox(height: 24),

            // Location Section
            _buildLocationSection(),
            const SizedBox(height: 24),

            // Trash Type Selection
            _buildTrashTypeSection(),
            const SizedBox(height: 24),

            // Severity Selection
            _buildSeveritySection(),
            const SizedBox(height: 24),

            // Description (Optional)
            _buildDescriptionSection(),
            const SizedBox(height: 24),

            // Safety Notice
            _buildSafetyNotice(),

            // Error Display
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.dangerRed,
                  ),
                ),
              ),
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
            Text('Photo Preview', style: AppTheme.headlineMedium),
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
            Text(
              'This photo will be analyzed by AI for verification',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
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
              ],
            ),
            const SizedBox(height: 12),

            if (widget.location != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'GPS: ${widget.location!.latitude.toStringAsFixed(6)}, ${widget.location!.longitude.toStringAsFixed(6)}',
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter or verify the address',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide an address';
                }
                return null;
              },
            ),
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
            Text('Trash Type', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.trashTypes.map((type) {
                final isSelected = _selectedTrashType == type;
                return FilterChip(
                  label: Text(Helpers.getTrashTypeDisplayName(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedTrashType = type);
                  },
                  selectedColor: AppTheme.lightGreen,
                  checkmarkColor: AppTheme.primaryGreen,
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
      'general': 'Common waste like food wrappers, papers, etc.',
      'recyclable': 'Plastic bottles, cans, cardboard that can be recycled',
      'hazardous':
          'Chemicals, batteries, medical waste - requires special handling',
      'large': 'Furniture, appliances, large items',
      'organic': 'Food waste, leaves, compostable materials',
    };

    return Text(
      descriptions[_selectedTrashType] ?? '',
      style: AppTheme.bodyMedium.copyWith(
        color: AppTheme.textSecondary,
        fontSize: 12,
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
            Text('Severity Level', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            Column(
              children: AppConstants.severityLevels.map((severity) {
                final isSelected = _selectedSeverity == severity;
                return RadioListTile<String>(
                  title: Text(_getSeverityDisplayName(severity)),
                  subtitle: Text(_getSeverityDescription(severity)),
                  value: severity,
                  groupValue: _selectedSeverity,
                  onChanged: (value) {
                    setState(() => _selectedSeverity = value!);
                  },
                  activeColor: Helpers.getSeverityColor(severity),
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
            Text(
              'Additional Details (Optional)',
              style: AppTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any additional information about this trash...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.warningOrange),
              const SizedBox(width: 8),
              Text(
                'Safety Notice',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If you see hazardous materials (chemicals, needles, etc.), do not attempt to clean them yourself. Report them and let professionals handle the cleanup.',
            style: AppTheme.bodyMedium,
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
      child: CustomButton(
        text: 'Submit Report',
        isLoading: _isSubmitting,
        onPressed: _submitReport,
        icon: Icons.send,
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

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

      // Create report model
      final report = TrashReportModel(
        id: const Uuid().v4(),
        imageURL: imageUrl,
        location: widget.location != null
            ? GeoPoint(widget.location!.latitude, widget.location!.longitude)
            : GeoPoint(0, 0), // Default if no location
        address: _addressController.text.trim(),
        reporterId: authProvider.user!.uid,
        timestamp: DateTime.now(),
        status: 'pending',
        visionVerified: false,
        visionLabels: [],
        visionConfidence: 0.0,
        moderatorReviewed: false,
        trashType: _selectedTrashType,
        severity: _selectedSeverity,
        safetyWarnings: [],
        estimatedEffort: _getEstimatedEffort(_selectedSeverity),
        votes: ReportVotes(upvotes: 0, downvotes: 0, voters: []),
        flagged: false,
        flagReasons: [],
      );

      // Submit to Firestore (this will trigger the Cloud Function)
      final reportId = await reportsProvider.createReport(report);

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReportSuccessScreen(reportId: reportId),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to submit report: $e';
        _isSubmitting = false;
      });
    }
  }

  String _getSeverityDisplayName(String severity) {
    switch (severity) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
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

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
