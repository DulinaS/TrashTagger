// lib/screens/report/report_form_screen.dart - Modern Vibrant Design (Completed)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/screens/location/location_picker_screen.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/storage_service.dart';
import '../../models/trash_report_model.dart';
import '../../themes/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/page_transitions.dart';
import 'report_success_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final File imageFile;

  const ReportFormScreen({Key? key, required this.imageFile}) : super(key: key);

  @override
  _ReportFormScreenState createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen>
    with TickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _formController;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _clearError();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _formController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    // Start animations
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) {
        _slideController.forward();
        _formController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _formController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: _buildBody(),
      ),
      bottomNavigationBar: SlideInAnimation(
        beginOffset: AnimationConstants.slideFromBottom,
        delay: const Duration(milliseconds: 600),
        child: _buildBottomBar(),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
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
                gradient: AppTheme.primaryGradient,
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
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: IconButton(
              icon: Icon(
                Icons.help_outline_rounded,
                color: AppTheme.textPrimary,
              ),
              onPressed: _showHelpDialog,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Image Preview Section
            SlideInAnimation(
              delay: AnimationConstants.microDelay,
              child: _buildImagePreview(),
            ),
            const SizedBox(height: 24),

            // Location Selection Section
            SlideInAnimation(
              delay: AnimationConstants.shortDelay,
              child: _buildLocationSection(),
            ),
            const SizedBox(height: 24),

            // Trash Type Selection
            SlideInAnimation(
              delay: AnimationConstants.mediumDelay,
              child: _buildTrashTypeSection(),
            ),
            const SizedBox(height: 24),

            // Severity Selection
            SlideInAnimation(
              delay: AnimationConstants.longDelay,
              child: _buildSeveritySection(),
            ),
            const SizedBox(height: 24),

            // Description Section
            SlideInAnimation(
              delay: AnimationConstants.extraLongDelay,
              child: _buildDescriptionSection(),
            ),
            const SizedBox(height: 24),

            // Estimated Effort Display
            ScaleInAnimation(
              delay: const Duration(milliseconds: 500),
              child: _buildEffortEstimateSection(),
            ),
            const SizedBox(height: 24),

            // Safety Notice
            ScaleInAnimation(
              delay: const Duration(milliseconds: 600),
              child: _buildSafetyNotice(),
            ),

            // Error Display
            if (_error != null) ...[
              const SizedBox(height: 16),
              SlideInAnimation(child: _buildErrorDisplay()),
            ],

            const SizedBox(height: 120), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
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
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Photo Preview',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              widget.imageFile,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 16,
                  color: AppTheme.infoBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This photo will be analyzed by AI for verification',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.infoBlue,
                      fontWeight: FontWeight.w500,
                    ),
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
                    colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
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
              const Spacer(),
              if (_selectedLocation == null)
                ModernStatusBadge(
                  status: 'pending',
                  customText: 'REQUIRED',
                  color: AppTheme.warningAmber,
                  showPulse: true,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected location display
          if (_selectedLocation != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.successGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Location Selected',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedAddress,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                    'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Select location button
          ModernGradientButton(
            text: _selectedLocation == null
                ? 'Select Location on Map'
                : 'Change Location',
            onPressed: _selectLocationOnMap,
            icon: _selectedLocation == null
                ? Icons.map_rounded
                : Icons.edit_location_rounded,
            gradient: _selectedLocation == null
                ? AppTheme.primaryGradient
                : LinearGradient(
                    colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                  ),
            width: double.infinity,
          ),

          if (_selectedLocation == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warningAmber.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select the exact location where you found the trash',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.warningAmber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrashTypeSection() {
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
                    colors: [AppTheme.accentPurple, AppTheme.accentCoral],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Trash Type',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.trashTypes.map((type) {
              final isSelected = _selectedTrashType == type;
              return ModernChip(
                label: Helpers.getTrashTypeDisplayName(type),
                icon: _getTrashTypeIcon(type),
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedTrashType = type;
                    _clearError();
                  });
                },
                selectedColor: _getTrashTypeColor(type),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          _getTrashTypeColor(type),
                          _getTrashTypeColor(type).withOpacity(0.8),
                        ],
                      )
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildTrashTypeDescription(),
        ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        descriptions[_selectedTrashType] ?? '',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSeveritySection() {
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
                  gradient: AppTheme.warningGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Severity Level',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: AppConstants.severityLevels.map((severity) {
              final isSelected = _selectedSeverity == severity;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Helpers.getSeverityColor(severity)
                        : AppTheme.borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? Helpers.getSeverityColor(severity).withOpacity(0.05)
                      : null,
                ),
                child: RadioListTile<String>(
                  title: Text(
                    _getSeverityDisplayName(severity),
                    style: AppTheme.titleMedium.copyWith(
                      color: isSelected
                          ? Helpers.getSeverityColor(severity)
                          : AppTheme.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _getSeverityDescription(severity),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
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
    );
  }

  Widget _buildDescriptionSection() {
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
                    colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Additional Details',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 200,
            style: AppTheme.bodyMedium,
            decoration: InputDecoration(
              hintText:
                  'Any additional information about this trash...\n'
                  'e.g., "Behind the bus stop", "Near the playground"',
              hintStyle: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textTertiary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryEmerald,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppTheme.backgroundPrimary,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: AppTheme.bodySmall.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            onChanged: (value) {
              setState(() {}); // Update counter
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEffortEstimateSection() {
    final effort = _getEstimatedEffort(_selectedSeverity);
    final points = _getExpectedPoints(_selectedSeverity);

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
                  gradient: AppTheme.successGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Cleanup Estimate',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.infoBlue.withOpacity(0.1),
                        AppTheme.primaryTeal.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.infoBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.timer_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        effort,
                        style: AppTheme.titleLarge.copyWith(
                          color: AppTheme.infoBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Estimated Time',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentAmber.withOpacity(0.1),
                        AppTheme.warningAmber.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentAmber.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.warningGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.stars_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$points pts',
                        style: AppTheme.titleLarge.copyWith(
                          color: AppTheme.accentAmber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Cleanup Reward',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice() {
    bool showHazardWarning = _selectedTrashType == 'hazardous';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: showHazardWarning
            ? AppTheme.errorRed.withOpacity(0.05)
            : AppTheme.warningAmber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showHazardWarning
              ? AppTheme.errorRed.withOpacity(0.3)
              : AppTheme.warningAmber.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showHazardWarning)
                PulseAnimation(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.dangerous_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              else
                Container(
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
              const SizedBox(width: 12),
              Text(
                showHazardWarning
                    ? 'Hazardous Material Warning'
                    : 'Safety Notice',
                style: AppTheme.titleMedium.copyWith(
                  color: showHazardWarning
                      ? AppTheme.errorRed
                      : AppTheme.warningAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: showHazardWarning
                  ? AppTheme.errorRed.withOpacity(0.1)
                  : AppTheme.warningAmber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              showHazardWarning
                  ? 'DANGER: Hazardous materials require special handling. Do NOT attempt to clean these yourself. Contact local authorities or hazmat disposal services immediately.'
                  : 'If you see hazardous materials (chemicals, needles, medical waste, etc.), do not attempt to clean them yourself. Report them and let professionals handle the cleanup.',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (showHazardWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This report will be flagged for professional cleanup only.',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
        child: ModernGradientButton(
          text: _isSubmitting ? 'Submitting Report...' : 'Submit Report',
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitReport,
          icon: _isSubmitting ? null : Icons.send_rounded,
          gradient: AppTheme.primaryGradient,
          width: double.infinity,
        ),
      ),
    );
  }

  // Location selection method
  Future<void> _selectLocationOnMap() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (context) => LocationPickerScreen(
            initialLocation: _selectedLocation,
            initialAddress: _selectedAddress,
            title: 'Trash Location?',
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
      final imageUrl = await StorageService.uploadTrashReportImage(
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
          PageTransitions.modernFadeScale(
            page: ReportSuccessScreen(reportId: reportId),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.help_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('How to Report Trash'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection('📍 Location Selection', [
                'Select the exact location where you found the trash',
                'Use the search or pin placement on the map',
                'Be as precise as possible for accurate cleanup',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('🗑️ Trash Type', [
                'Choose the category that best describes the waste',
                'Select "Hazardous" for dangerous materials',
                'When in doubt, choose "General"',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('⚡ Severity Level', [
                'Low: Small amount, quick cleanup',
                'Medium: Moderate effort required',
                'High: Large amount or difficult cleanup',
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 What Happens Next',
                      style: AppTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• AI analyzes your photo for verification\n'
                      '• Report becomes available as a cleanup challenge\n'
                      '• Community members can accept and complete it\n'
                      '• You earn points when it\'s successfully cleaned!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ModernGradientButton(
            text: 'Got it!',
            onPressed: () => Navigator.pop(context),
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $item', style: AppTheme.bodyMedium),
          ),
        ),
      ],
    );
  }

  // Helper methods for UI data
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

  Color _getTrashTypeColor(String trashType) {
    switch (trashType) {
      case 'general':
        return AppTheme.textSecondary;
      case 'recyclable':
        return AppTheme.primaryTeal;
      case 'hazardous':
        return AppTheme.errorRed;
      case 'large':
        return AppTheme.accentPurple;
      case 'organic':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
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
}
