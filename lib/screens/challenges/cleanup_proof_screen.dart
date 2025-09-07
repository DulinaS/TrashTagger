// lib/screens/challenges/cleanup_proof_screen.dart - Modern Vibrant Design
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/trash_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/page_transitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CleanupProofScreen extends StatefulWidget {
  final TrashReportModel challenge;

  const CleanupProofScreen({Key? key, required this.challenge})
    : super(key: key);

  @override
  _CleanupProofScreenState createState() => _CleanupProofScreenState();
}

class _CleanupProofScreenState extends State<CleanupProofScreen>
    with TickerProviderStateMixin {
  // Existing variables
  File? _proofImage;
  bool _isSubmitting = false;
  final StorageService _storageService = StorageService();
  final _notesController = TextEditingController();

  // Enhanced location variables
  Position? _currentGPSPosition;
  bool _locationVerified = false;
  double? _distanceFromReported;
  bool _isLoadingLocation = false;
  LocationPermission? _currentPermission;
  String _locationStatus = 'not_checked';

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    _checkInitialLocationStatus();

    // Start animations
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) {
        _slideController.forward();
        _bounceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // [Keep all existing location methods unchanged]
  Future<void> _checkInitialLocationStatus() async {
    try {
      _currentPermission = await Geolocator.checkPermission();
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      setState(() {
        if (_currentPermission == LocationPermission.denied ||
            _currentPermission == LocationPermission.deniedForever) {
          _locationStatus = 'denied';
        } else if (!serviceEnabled) {
          _locationStatus = 'service_disabled';
        } else {
          _locationStatus = 'ready';
        }
      });
    } catch (e) {
      setState(() => _locationStatus = 'failed');
    }
  }

  Future<void> _verifyCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'checking';
    });

    try {
      await _ensureLocationPermissions();
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      _currentGPSPosition = await _getLocationWithFallback();

      final challengeLocation = widget.challenge.location;
      _distanceFromReported = Geolocator.distanceBetween(
        _currentGPSPosition!.latitude,
        _currentGPSPosition!.longitude,
        challengeLocation.latitude,
        challengeLocation.longitude,
      );

      setState(() {
        _locationVerified = _distanceFromReported! <= 100;
        _locationStatus = 'success';
      });

      _showLocationResult();
    } on LocationServiceDisabledException {
      setState(() => _locationStatus = 'service_disabled');
      _showLocationServiceDialog();
    } on PermissionDeniedException {
      setState(() => _locationStatus = 'denied');
      _showPermissionDeniedDialog();
    } on TimeoutException {
      setState(() => _locationStatus = 'timeout');
      _showTimeoutDialog();
    } catch (e) {
      setState(() => _locationStatus = 'failed');
      _showGenericErrorDialog(e.toString());
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _ensureLocationPermissions() async {
    _currentPermission = await Geolocator.checkPermission();

    if (_currentPermission == LocationPermission.denied) {
      _currentPermission = await Geolocator.requestPermission();
    }

    if (_currentPermission == LocationPermission.denied ||
        _currentPermission == LocationPermission.deniedForever) {
      throw PermissionDeniedException();
    }
  }

  Future<Position> _getLocationWithFallback() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } on TimeoutException {
      print('High accuracy timeout, trying medium...');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } on TimeoutException {
      print('Medium accuracy timeout, trying low...');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (e) {
      throw TimeoutException(
        'GPS could not get location after all attempts',
        const Duration(seconds: 25),
      );
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Resubmission Notice
                if (widget.challenge.status == 'disputed')
                  SlideInAnimation(
                    delay: AnimationConstants.microDelay,
                    child: _buildResubmissionNotice(),
                  ),

                // Original Photo Section
                SlideInAnimation(
                  delay: AnimationConstants.shortDelay,
                  child: _buildOriginalPhotoSection(),
                ),
                const SizedBox(height: 24),

                // Location Verification Section
                SlideInAnimation(
                  delay: AnimationConstants.mediumDelay,
                  child: _buildLocationVerificationSection(),
                ),
                const SizedBox(height: 24),

                // Proof Photo Section
                SlideInAnimation(
                  delay: AnimationConstants.longDelay,
                  child: _buildProofPhotoSection(),
                ),
                const SizedBox(height: 24),

                // Notes Section
                SlideInAnimation(
                  delay: AnimationConstants.extraLongDelay,
                  child: _buildNotesSection(),
                ),
                const SizedBox(height: 24),

                // Safety Reminder
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 600),
                  child: _buildSafetyReminder(),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SlideInAnimation(
        beginOffset: AnimationConstants.slideFromBottom,
        delay: const Duration(milliseconds: 700),
        child: _buildSubmitButton(),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
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
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cleanup Proof',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
    );
  }

  Widget _buildResubmissionNotice() {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      backgroundColor: AppTheme.warningAmber.withOpacity(0.1),
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
                'Cleanup Proof Disputed',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.warningAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your previous proof photo was disputed. Please submit a new photo that clearly shows:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (widget.challenge.proofVerification?.reasons?.isNotEmpty ?? false)
            ...widget.challenge.proofVerification!.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 8,
                      color: AppTheme.warningAmber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
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

  Widget _buildOriginalPhotoSection() {
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
                child: Icon(Icons.photo_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Original Trash Report',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: widget.challenge.imageURL,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => ShimmerAnimation(
                child: Container(
                  height: 200,
                  color: AppTheme.backgroundPrimary,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(height: 8),
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
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppTheme.primaryEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.challenge.address,
                    style: AppTheme.bodyMedium.copyWith(
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

  Widget _buildLocationVerificationSection() {
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
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Location Verification',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Challenge location display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryEmerald.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cleanup Location:',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.challenge.address, style: AppTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Location status display
          _buildLocationStatusDisplay(),
          const SizedBox(height: 16),

          // Action button
          _buildLocationActionButton(),

          // Additional info based on status
          if (_locationStatus == 'denied') _buildPermissionInfo(),
          if (_locationStatus == 'service_disabled') _buildServiceInfo(),
          if (_locationStatus == 'timeout') _buildTimeoutInfo(),
        ],
      ),
    );
  }

  Widget _buildLocationStatusDisplay() {
    switch (_locationStatus) {
      case 'checking':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              PulseAnimation(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Getting your location...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.infoBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case 'success':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                (_locationVerified
                        ? AppTheme.successGreen
                        : AppTheme.warningAmber)
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  (_locationVerified
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber)
                      .withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _locationVerified
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _locationVerified
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _locationVerified
                        ? 'Location Verified ✅'
                        : 'Location Detected ⚠️',
                    style: AppTheme.labelMedium.copyWith(
                      color: _locationVerified
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'You are ${_distanceFromReported?.toInt() ?? '?'}m from the cleanup site',
                style: AppTheme.bodyMedium,
              ),
              if (!_locationVerified &&
                  _distanceFromReported != null &&
                  _distanceFromReported! > 100) ...[
                const SizedBox(height: 8),
                Text(
                  'Consider moving closer to the exact location for better verification',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'denied':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_disabled_rounded,
                color: AppTheme.errorRed,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location permission denied',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorRed),
                ),
              ),
            ],
          ),
        );

      case 'service_disabled':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningAmber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_disabled_rounded,
                color: AppTheme.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location services are disabled',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.warningAmber,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'timeout':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningAmber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: AppTheme.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'GPS timeout - unable to get precise location',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.warningAmber,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'failed':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_rounded, color: AppTheme.errorRed, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location verification failed',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorRed),
                ),
              ),
            ],
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.textSecondary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_searching_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Tap to verify your location',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildLocationActionButton() {
    String buttonText;
    VoidCallback? onPressed;
    LinearGradient? gradient;
    IconData icon;

    switch (_locationStatus) {
      case 'checking':
        buttonText = 'Getting Location...';
        onPressed = null;
        gradient = LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        );
        icon = Icons.my_location_rounded;
        break;
      case 'success':
        buttonText = 'Verify Again';
        onPressed = _verifyCurrentLocation;
        gradient = LinearGradient(
          colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
        );
        icon = Icons.refresh_rounded;
        break;
      case 'denied':
        buttonText = 'Grant Permission';
        onPressed = _openAppSettings;
        gradient = AppTheme.warningGradient;
        icon = Icons.settings_rounded;
        break;
      case 'service_disabled':
        buttonText = 'Enable Location Services';
        onPressed = _openLocationSettings;
        gradient = AppTheme.warningGradient;
        icon = Icons.location_on_rounded;
        break;
      default:
        buttonText = 'Verify My Location';
        onPressed = _verifyCurrentLocation;
        gradient = AppTheme.primaryGradient;
        icon = Icons.my_location_rounded;
    }

    return ModernGradientButton(
      text: buttonText,
      onPressed: onPressed,
      gradient: gradient,
      icon: _isLoadingLocation ? null : icon,
      isLoading: _isLoadingLocation,
      width: double.infinity,
    );
  }

  Widget _buildPermissionInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Location permission is needed to verify you are at the cleanup site. You can still submit without it.',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Please enable location services in your device settings to verify your location.',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildTimeoutInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'GPS is taking too long. Try moving to an area with clear sky view, or submit without location verification.',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildProofPhotoSection() {
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
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Cleanup Proof Photo',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_proofImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _proofImage!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ModernGradientButton(
                    text: 'Retake Photo',
                    onPressed: _takeNewPhoto,
                    icon: Icons.camera_alt_rounded,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernGradientButton(
                    text: 'Remove',
                    onPressed: _removePhoto,
                    icon: Icons.delete_rounded,
                    gradient: AppTheme.errorGradient,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryEmerald.withOpacity(0.1),
                    AppTheme.primaryTeal.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryEmerald.withOpacity(0.3),
                  width: 2,
                  style: BorderStyle.values[1], // dashed effect
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleInAnimation(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Take a photo of the cleaned area',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.primaryEmerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show the same location after cleanup',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ModernGradientButton(
                    text: 'Capture',
                    onPressed: _takePhoto,
                    icon: Icons.camera_alt_rounded,
                    gradient: AppTheme.primaryGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernGradientButton(
                    text: 'Gallery',
                    onPressed: _pickFromGallery,
                    icon: Icons.photo_library_rounded,
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
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
                child: Icon(Icons.notes_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Cleanup Notes (Optional)',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _notesController,
            hint:
                'Add any notes about the cleanup process, tools used, or challenges faced...',
            maxLines: 4,
            enableFloatingLabel: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyReminder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.infoBlue.withOpacity(0.1),
            AppTheme.primaryTeal.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Cleanup Guidelines',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.infoBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuidelineItem(
                'Take the photo from the same angle as the original report',
              ),
              _buildGuidelineItem('Ensure all visible trash has been removed'),
              _buildGuidelineItem(
                'Dispose of waste properly in appropriate bins',
              ),
              _buildGuidelineItem(
                'If hazardous materials were involved, confirm safe disposal',
              ),
              _buildGuidelineItem(
                'Your proof photo will be reviewed by the community',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.infoBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
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
          text: _isSubmitting
              ? 'Submitting...'
              : (widget.challenge.status == 'disputed'
                    ? 'Resubmit Cleanup Proof'
                    : 'Submit Cleanup Proof'),
          icon: _isSubmitting ? null : Icons.check_circle_rounded,
          isLoading: _isSubmitting,
          onPressed: _proofImage != null ? _submitProof : null,
          gradient: widget.challenge.status == 'disputed'
              ? AppTheme.warningGradient
              : AppTheme.primaryGradient,
          width: double.infinity,
        ),
      ),
    );
  }

  // [Keep all existing photo and submission methods unchanged]
  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _takeNewPhoto() {
    _takePhoto();
  }

  void _removePhoto() {
    setState(() {
      _proofImage = null;
    });
  }

  Future<void> _submitProof() async {
    if (_proofImage == null) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final proofURL = await StorageService.uploadCleanupProofImage(
        _proofImage!,
        widget.challenge.id,
        authProvider.user!.uid,
      );

      final data = {
        'proofURL': proofURL,
        'proofTimestamp': FieldValue.serverTimestamp(),
        'cleanupNotes': _notesController.text.trim(),
        'status': 'processing',
        'proofMetadata': {
          'submissionLocation': _currentGPSPosition != null
              ? GeoPoint(
                  _currentGPSPosition!.latitude,
                  _currentGPSPosition!.longitude,
                )
              : null,
          'locationVerified': _locationVerified,
          'distanceFromReported': _distanceFromReported,
          'deviceInfo': {
            'platform': Platform.operatingSystem,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          'verificationMethod': 'enhanced_maps',
        },
      };

      if (widget.challenge.status == 'disputed') {
        data['previousProofURL'] = widget.challenge.proofURL!;
        data['resubmissionAttempt'] = true;
        data['disputeResolved'] = false;
      }

      await FirebaseFirestore.instance
          .collection('trashReports')
          .doc(widget.challenge.id)
          .update(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.challenge.status == 'disputed'
                        ? 'Proof resubmitted successfully! Under review.'
                        : 'Cleanup proof submitted! Under review.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showError('Failed to submit proof: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // [Keep all existing helper methods unchanged]
  void _showLocationResult() {
    final message = _locationVerified
        ? '✅ Perfect! You are ${_distanceFromReported!.toInt()}m from the cleanup site'
        : '⚠️ You are ${_distanceFromReported!.toInt()}m from the cleanup site';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _locationVerified
            ? AppTheme.primaryEmerald
            : AppTheme.warningAmber,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission'),
        content: Text(
          'Location permission was denied. You can still submit cleanup proof, but verification will rely entirely on photo analysis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Without Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Services Disabled'),
        content: Text(
          'Please enable location services in your device settings to verify your location at the cleanup site.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Without Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openLocationSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('GPS Timeout'),
        content: Text(
          'GPS is taking too long to get your location. This often happens indoors or in areas with poor satellite visibility.\n\nYou can:\n• Try again in an open area\n• Submit without location verification',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Without Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyCurrentLocation();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showGenericErrorDialog(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Location error: $error')),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openAppSettings() {
    Geolocator.openAppSettings();
  }

  void _openLocationSettings() {
    Geolocator.openLocationSettings();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Custom exception class
class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException([this.message = 'Location permission denied']);
  @override
  String toString() => 'PermissionDeniedException: $message';
}
