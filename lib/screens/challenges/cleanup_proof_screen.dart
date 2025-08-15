// lib/screens/challenges/cleanup_proof_screen.dart
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
import '../../widgets/common/custom_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CleanupProofScreen extends StatefulWidget {
  final TrashReportModel challenge;

  const CleanupProofScreen({Key? key, required this.challenge})
    : super(key: key);

  @override
  _CleanupProofScreenState createState() => _CleanupProofScreenState();
}

class _CleanupProofScreenState extends State<CleanupProofScreen> {
  // Your existing variables...
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
  String _locationStatus =
      'not_checked'; // not_checked, checking, success, failed, denied

  @override
  void initState() {
    super.initState();
    _checkInitialLocationStatus();
  }

  // Check location status when screen loads (no auto-detection, just status check)
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

  // Main location verification method - much more robust
  Future<void> _verifyCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'checking';
    });

    try {
      // Step 1: Check and request permissions properly
      await _ensureLocationPermissions();

      // Step 2: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // Step 3: Get location with progressive fallback
      _currentGPSPosition = await _getLocationWithFallback();

      // Step 4: Calculate distance and update UI
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

  // Robust permission handling
  Future<void> _ensureLocationPermissions() async {
    _currentPermission = await Geolocator.checkPermission();

    if (_currentPermission == LocationPermission.denied) {
      // First time asking
      _currentPermission = await Geolocator.requestPermission();
    }

    if (_currentPermission == LocationPermission.denied ||
        _currentPermission == LocationPermission.deniedForever) {
      throw PermissionDeniedException();
    }
  }

  // Progressive location detection with fallbacks
  Future<Position> _getLocationWithFallback() async {
    // Try high accuracy first (5 seconds)
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } on TimeoutException {
      print('High accuracy timeout, trying medium...');
    }

    // Fallback to medium accuracy (8 seconds)
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } on TimeoutException {
      print('Medium accuracy timeout, trying low...');
    }

    // Final fallback to low accuracy (12 seconds)
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

  // Enhanced UI for location status
  Widget _buildLocationVerificationSection() {
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
                Text('Location Verification', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),

            // Challenge location display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cleanup Location:', style: AppTheme.labelMedium),
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
      ),
    );
  }

  Widget _buildLocationStatusDisplay() {
    switch (_locationStatus) {
      case 'checking':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.infoBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Getting your location...', style: AppTheme.bodyMedium),
            ],
          ),
        );

      case 'success':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                (_locationVerified
                        ? AppTheme.primaryGreen
                        : AppTheme.warningOrange)
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _locationVerified
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color: _locationVerified
                        ? AppTheme.primaryGreen
                        : AppTheme.warningOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _locationVerified
                        ? 'Location Verified ✅'
                        : 'Location Detected ⚠️',
                    style: AppTheme.labelMedium.copyWith(
                      color: _locationVerified
                          ? AppTheme.primaryGreen
                          : AppTheme.warningOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You are ${_distanceFromReported?.toInt() ?? '?'}m from the cleanup site',
                style: AppTheme.bodyMedium,
              ),
              if (!_locationVerified &&
                  _distanceFromReported != null &&
                  _distanceFromReported! > 100) ...[
                const SizedBox(height: 4),
                Text(
                  'Consider moving closer to the exact location for better verification',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );

      case 'denied':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.dangerRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_disabled,
                color: AppTheme.dangerRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location permission denied',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.dangerRed,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'service_disabled':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_disabled,
                color: AppTheme.warningOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location services are disabled',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.warningOrange,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'timeout':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.warningOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GPS timeout - unable to get precise location',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.warningOrange,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'failed':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.dangerRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: AppTheme.dangerRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location verification failed',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.dangerRed,
                  ),
                ),
              ),
            ],
          ),
        );

      default: // 'not_checked' or 'ready'
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_searching,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
    Color? backgroundColor;

    switch (_locationStatus) {
      case 'checking':
        buttonText = 'Getting Location...';
        onPressed = null;
        break;
      case 'success':
        buttonText = 'Verify Again';
        onPressed = _verifyCurrentLocation;
        backgroundColor = AppTheme.infoBlue;
        break;
      case 'denied':
        buttonText = 'Grant Permission';
        onPressed = _openAppSettings;
        backgroundColor = AppTheme.warningOrange;
        break;
      case 'service_disabled':
        buttonText = 'Enable Location Services';
        onPressed = _openLocationSettings;
        backgroundColor = AppTheme.warningOrange;
        break;
      default:
        buttonText = 'Verify My Location';
        onPressed = _verifyCurrentLocation;
        backgroundColor = AppTheme.primaryGreen;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _isLoadingLocation
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(_getLocationButtonIcon()),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  IconData _getLocationButtonIcon() {
    switch (_locationStatus) {
      case 'success':
        return Icons.refresh;
      case 'denied':
        return Icons.settings;
      case 'service_disabled':
        return Icons.location_on;
      default:
        return Icons.my_location;
    }
  }

  // Helper info widgets
  Widget _buildPermissionInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Location permission is needed to verify you are at the cleanup site. You can still submit without it.',
        style: AppTheme.bodyMedium.copyWith(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Please enable location services in your device settings to verify your location.',
        style: AppTheme.bodyMedium.copyWith(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTimeoutInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'GPS is taking too long. Try moving to an area with clear sky view, or submit without location verification.',
        style: AppTheme.bodyMedium.copyWith(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  // Helper methods for better UX
  void _showLocationResult() {
    final message = _locationVerified
        ? '✅ Perfect! You are ${_distanceFromReported!.toInt()}m from the cleanup site'
        : '⚠️ You are ${_distanceFromReported!.toInt()}m from the cleanup site';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _locationVerified
            ? AppTheme.primaryGreen
            : AppTheme.warningOrange,
        duration: Duration(seconds: 3),
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
        content: Text('Location error: $error'),
        backgroundColor: AppTheme.dangerRed,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _openAppSettings() {
    Geolocator.openAppSettings();
  }

  void _openLocationSettings() {
    Geolocator.openLocationSettings();
  }

  // Don't forget to add this to your build method:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (widget.challenge.status == 'disputed')
              _buildResubmissionNotice(),
            _buildOriginalPhotoSection(),
            const SizedBox(height: 24),

            // ADD THIS LINE to show location verification:
            _buildLocationVerificationSection(),
            const SizedBox(height: 24),

            _buildProofPhotoSection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
            const SizedBox(height: 24),
            _buildSafetyReminder(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildResubmissionNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningYellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.warningYellow),
              const SizedBox(width: 8),
              Text(
                'Cleanup Proof Disputed',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.warningYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your previous proof photo was disputed. Please submit a new photo that clearly shows:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (widget.challenge.proofVerification?.reasons?.isNotEmpty ??
              false) ...[
            ...widget.challenge.proofVerification!.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: AppTheme.bodyMedium),
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
        ],
      ),
    );
  }

  Widget _buildOriginalPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Trash Report', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.challenge.imageURL,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  child: const Center(child: Icon(Icons.error)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${widget.challenge.address}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cleanup Proof Photo', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),

            if (_proofImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _proofImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takeNewPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Take a photo of the cleaned area',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGreen,
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
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cleanup Notes (Optional)', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Add any notes about the cleanup process, tools used, or challenges faced...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyReminder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info, color: AppTheme.infoBlue),
              const SizedBox(width: 8),
              Text(
                'Cleanup Guidelines',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.infoBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Take the photo from the same angle as the original report\n'
            '• Ensure all visible trash has been removed\n'
            '• Dispose of waste properly in appropriate bins\n'
            '• If hazardous materials were involved, confirm safe disposal\n'
            '• Your proof photo will be reviewed by the community',
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
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
          text: _isSubmitting
              ? 'Submitting...'
              : (widget.challenge.status == 'disputed'
                    ? 'Resubmit Cleanup Proof'
                    : 'Submit Cleanup Proof'),
          icon: Icons.check_circle,
          isLoading: _isSubmitting,
          onPressed: _proofImage != null ? _submitProof : null,
          backgroundColor: widget.challenge.status == 'disputed'
              ? AppTheme.warningYellow
              : AppTheme.primaryGreen,
        ),
      ),
    );
  }

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

      final proofURL = await _storageService.uploadCleanupProofImage(
        _proofImage!,
        widget.challenge.id,
        authProvider.user!.uid,
      );

      // Enhanced data with location verification
      final data = {
        'proofURL': proofURL,
        'proofTimestamp': FieldValue.serverTimestamp(),
        'cleanupNotes': _notesController.text.trim(),
        'status': 'processing',

        // NEW: Enhanced verification metadata
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
            content: Text(
              widget.challenge.status == 'disputed'
                  ? 'Proof resubmitted successfully! Under review.'
                  : 'Cleanup proof submitted! Under review.',
            ),
            backgroundColor: AppTheme.primaryGreen,
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

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.dangerRed),
    );
  }
}

// Add this custom exception class at the top of your file:
class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException([this.message = 'Location permission denied']);
  @override
  String toString() => 'PermissionDeniedException: $message';
}


/* class _CleanupProofScreenState extends State<CleanupProofScreen> {
  File? _proofImage;
  bool _isSubmitting = false;
  final StorageService _storageService = StorageService();
  final _notesController = TextEditingController();

  Position? _currentGPSPosition;
  bool _locationVerified = false;
  double? _distanceFromReported;
  bool _isLoadingLocation = false; // Added to fix undefined name error
  LocationPermission? _currentPermission;
  String _locationStatus = 'not_checked';

  bool get canResubmit => widget.challenge.status == 'disputed';

  bool get isFirstSubmission =>
      widget.challenge.proofURL == null || widget.challenge.proofURL!.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.challenge.status == 'disputed'
              ? 'Resubmit Cleanup Proof'
              : 'Submit Cleanup Proof',
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show resubmission notice only for disputed status
            if (widget.challenge.status == 'disputed')
              _buildResubmissionNotice(),
            _buildOriginalPhotoSection(),
            const SizedBox(height: 24),

            _buildLocationVerificationSection(),
            const SizedBox(height: 24),

            // Proof Photo Section
            _buildProofPhotoSection(),
            const SizedBox(height: 24),

            // Notes Section
            _buildNotesSection(),
            const SizedBox(height: 24),

            // Safety Reminder
            _buildSafetyReminder(),
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }
  // Check location status when screen loads (no auto-detection, just status check)
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

  Widget _buildLocationVerificationSection() {
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
                Text('Location Verification', style: AppTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),

            // Show challenge location
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Challenge Location:', style: AppTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(widget.challenge.address, style: AppTheme.bodyMedium),
                  const SizedBox(height: 8),

                  // GPS verification status
                  if (_currentGPSPosition != null) ...[
                    Row(
                      children: [
                        Icon(
                          _locationVerified
                              ? Icons.check_circle
                              : Icons.warning,
                          size: 16,
                          color: _locationVerified
                              ? AppTheme.primaryGreen
                              : AppTheme.warningOrange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _locationVerified
                              ? 'You are at the challenge location'
                              : 'You are ${_distanceFromReported?.toInt()}m away',
                          style: AppTheme.bodyMedium.copyWith(
                            color: _locationVerified
                                ? AppTheme.primaryGreen
                                : AppTheme.warningOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.gps_off,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GPS verification unavailable',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_currentGPSPosition != null &&
                      _distanceFromReported != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getDistanceColor(
                          _distanceFromReported!,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getDistanceColor(
                            _distanceFromReported!,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getDistanceIcon(_distanceFromReported!),
                            color: _getDistanceColor(_distanceFromReported!),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getDistanceMessage(_distanceFromReported!),
                              style: AppTheme.bodyMedium.copyWith(
                                color: _getDistanceColor(
                                  _distanceFromReported!,
                                ),
                                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 12),

            // Verify location button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _verifyCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Verify My Location'),
              ),
            ),

            if (!_locationVerified && _distanceFromReported != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'For best verification results, please go to the exact location where the trash was reported.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.warningOrange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getDistanceColor(double distance) {
    if (distance <= 100) return AppTheme.primaryGreen;
    if (distance <= 400) return AppTheme.warningOrange;
    return AppTheme.dangerRed;
  }

  IconData _getDistanceIcon(double distance) {
    if (distance <= 100) return Icons.check_circle;
    if (distance <= 400) return Icons.warning_amber;
    return Icons.error;
  }

  String _getDistanceMessage(double distance) {
    if (distance <= 100) {
      return 'Perfect! You are ${distance.toInt()}m from the cleanup site';
    } else if (distance <= 400) {
      return 'Good! You are ${distance.toInt()}m from the cleanup site';
    } else {
      return 'You are ${distance.toInt()}m away - consider getting closer for better verification';
    }
  }

  /* // ADD: Location verification method
  Future<void> _verifyCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        return;
      }

      _currentGPSPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final challengeLocation = widget.challenge.location;
      _distanceFromReported = Geolocator.distanceBetween(
        _currentGPSPosition!.latitude,
        _currentGPSPosition!.longitude,
        challengeLocation.latitude,
        challengeLocation.longitude,
      );

      setState(() {
        _locationVerified = _distanceFromReported! <= 100; // Within 100m
      });

      if (!_locationVerified) {
        _showLocationWarningDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Location verified! You are at the challenge location.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to verify location: $e'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
    }
  } */
  /* Future<void> _verifyCurrentLocation() async {
    if (_isLoadingLocation) return; // Prevent multiple calls

    setState(() => _isLoadingLocation = true);

    try {
      // Check permissions first
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Get position with proper timeout handling
      _currentGPSPosition =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy
                .medium, // Changed from high for faster response
            timeLimit: const Duration(seconds: 10), // Reduced timeout
          ).timeout(
            const Duration(seconds: 12), // Extra safety timeout
            onTimeout: () {
              throw TimeoutException(
                'GPS timeout - please try again',
                const Duration(seconds: 12),
              );
            },
          );

      final challengeLocation = widget.challenge.location;
      _distanceFromReported = Geolocator.distanceBetween(
        _currentGPSPosition!.latitude,
        _currentGPSPosition!.longitude,
        challengeLocation.latitude,
        challengeLocation.longitude,
      );

      setState(() {
        _locationVerified = _distanceFromReported! <= 100; // Within 100m
      });

      // Show appropriate feedback
      if (_locationVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Location verified! You are ${_distanceFromReported!.toInt()}m from the cleanup site.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } else if (_distanceFromReported! <= 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ You are ${_distanceFromReported!.toInt()}m from the reported location.',
            ),
            backgroundColor: AppTheme.warningOrange,
            action: SnackBarAction(
              label: 'I understand',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        _showLocationWarningDialog();
      }
    } on TimeoutException catch (e) {
      print('GPS Timeout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'GPS timeout - try moving to an open area with clear sky view',
            ),
            backgroundColor: AppTheme.warningOrange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enable location services in your device settings',
            ),
            backgroundColor: AppTheme.warningOrange,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
    } catch (e) {
      print('Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get location: ${e.toString()}'),
            backgroundColor: AppTheme.warningOrange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  } */
  Future<void> _verifyCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'checking';
    });

    try {
      // Step 1: Check and request permissions properly
      await _ensureLocationPermissions();

      // Step 2: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // Step 3: Get location with progressive fallback
      _currentGPSPosition = await _getLocationWithFallback();

      // Step 4: Calculate distance and update UI
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

  void _showLocationWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Notice'),
        content: Text(
          'You appear to be ${_distanceFromReported?.toInt()}m away from the reported location. '
          'For best verification results, please go to the exact spot where the trash was found.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('I understand'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission'),
        content: Text(
          'Location verification helps confirm you are at the cleanup site. You can still submit proof without it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Without GPS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildResubmissionNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningYellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.warningYellow),
              const SizedBox(width: 8),
              Text(
                'Cleanup Proof Disputed',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.warningYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your previous proof photo was disputed. Please submit a new photo that clearly shows:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (widget.challenge.proofVerification?.reasons?.isNotEmpty ??
              false) ...[
            ...widget.challenge.proofVerification!.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: AppTheme.bodyMedium),
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
        ],
      ),
    );
  }

  Widget _buildOriginalPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Trash Report', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.challenge.imageURL,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  child: const Center(child: Icon(Icons.error)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${widget.challenge.address}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cleanup Proof Photo', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),

            if (_proofImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _proofImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takeNewPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Take a photo of the cleaned area',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGreen,
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
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cleanup Notes (Optional)', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Add any notes about the cleanup process, tools used, or challenges faced...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyReminder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info, color: AppTheme.infoBlue),
              const SizedBox(width: 8),
              Text(
                'Cleanup Guidelines',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.infoBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Take the photo from the same angle as the original report\n'
            '• Ensure all visible trash has been removed\n'
            '• Dispose of waste properly in appropriate bins\n'
            '• If hazardous materials were involved, confirm safe disposal\n'
            '• Your proof photo will be reviewed by the community',
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
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
          text: _isSubmitting
              ? 'Submitting...'
              : (widget.challenge.status == 'disputed'
                    ? 'Resubmit Cleanup Proof'
                    : 'Submit Cleanup Proof'),
          icon: Icons.check_circle,
          isLoading: _isSubmitting,
          onPressed: _proofImage != null ? _submitProof : null,
          backgroundColor: widget.challenge.status == 'disputed'
              ? AppTheme.warningYellow
              : AppTheme.primaryGreen,
        ),
      ),
    );
  }

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

  /* Future<void> _submitProof() async {
    if (_proofImage == null) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final proofURL = await _storageService.uploadCleanupProofImage(
        _proofImage!,
        widget.challenge.id,
        authProvider.user!.uid,
      );

      final data = {
        'proofURL': proofURL,
        'proofTimestamp': FieldValue.serverTimestamp(),
        'cleanupNotes': _notesController.text.trim(),
        'status': 'processing',
      };

      // Add resubmission-specific fields
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
            content: Text(
              widget.challenge.status == 'disputed'
                  ? 'Proof resubmitted successfully! Under review.'
                  : 'Cleanup proof submitted! Under review.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showError('Failed to submit proof: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  } */
  Future<void> _submitProof() async {
    if (_proofImage == null) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final proofURL = await _storageService.uploadCleanupProofImage(
        _proofImage!,
        widget.challenge.id,
        authProvider.user!.uid,
      );

      // Enhanced data with location verification
      final data = {
        'proofURL': proofURL,
        'proofTimestamp': FieldValue.serverTimestamp(),
        'cleanupNotes': _notesController.text.trim(),
        'status': 'processing',

        // NEW: Enhanced verification metadata
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
            content: Text(
              widget.challenge.status == 'disputed'
                  ? 'Proof resubmitted successfully! Under review.'
                  : 'Cleanup proof submitted! Under review.',
            ),
            backgroundColor: AppTheme.primaryGreen,
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

  // In your CleanupProofScreen - add this to show verification status
  Widget _buildVerificationStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.security, color: AppTheme.infoBlue),
            SizedBox(height: 8),
            Text('AI Verification', style: AppTheme.headlineMedium),
            SizedBox(height: 8),
            Text(
              'Your proof will be automatically verified using AI to ensure it shows the same location cleaned up.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.dangerRed),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
 */