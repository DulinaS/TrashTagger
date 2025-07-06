// lib/screens/report/camera_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../themes/app_theme.dart';
import 'report_form_screen.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isLoading = false;
  Position? _currentPosition;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _showPermissionDialog('Camera');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        _showError('No cameras available on this device');
        return;
      }

      // Initialize camera controller with back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Request location permission
      final locationPermission = await Permission.location.request();
      if (!locationPermission.isGranted) {
        _showPermissionDialog('Location');
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError(
          'Location services are disabled. Please enable them in settings.',
        );
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Get address from coordinates
      if (_currentPosition != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          _currentAddress =
              [
                    placemark.street,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country,
                  ]
                  .where((element) => element != null && element.isNotEmpty)
                  .join(', ');
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error getting location: $e');
      // Continue without location - user can add it manually
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Report Trash'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(child: CameraPreview(_cameraController!)),

        // Top Information Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentAddress != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _currentAddress!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Point your camera at trash and take a photo',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: _buildBottomControls(),
          ),
        ),

        // Loading Overlay
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Processing image...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Gallery Button
            IconButton(
              onPressed: _pickFromGallery,
              icon: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 28,
              ),
            ),

            // Capture Button
            GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Switch Camera Button
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Tap to capture or select from gallery',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized || _isLoading) return;

    try {
      setState(() => _isLoading = true);

      final XFile image = await _cameraController!.takePicture();
      _proceedWithImage(File(image.path));
    } catch (e) {
      _showError('Failed to take picture: $e');
    } finally {
      setState(() => _isLoading = false);
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
        _proceedWithImage(File(image.path));
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    try {
      await _cameraController?.dispose();

      // Switch to the other camera
      final currentCamera = _cameraController!.description;
      final newCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection != currentCamera.lensDirection,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to switch camera: $e');
    }
  }

  void _proceedWithImage(File imageFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportFormScreen(
          imageFile: imageFile,
          location: _currentPosition,
          address: _currentAddress,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerRed,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showPermissionDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text(
          'TrashTagger needs $permission access to help you report trash. Please grant permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Report Trash'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📸 Take a clear photo of the trash'),
            SizedBox(height: 8),
            Text('📍 Make sure location is accurate'),
            SizedBox(height: 8),
            Text('🏷️ Select the type of trash'),
            SizedBox(height: 8),
            Text('✅ Submit for AI verification'),
            SizedBox(height: 16),
            Text(
              'Your report will be analyzed by AI and made available for cleanup challenges!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
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

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
