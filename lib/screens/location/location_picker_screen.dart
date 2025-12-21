// lib/screens/location/location_picker_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/api_keys.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final String title;

  const LocationPickerScreen({
    Key? key,
    this.initialLocation,
    this.initialAddress,
    this.title = 'Select Location',
  }) : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(6.9271, 79.8612); // Default: Colombo
  String _selectedAddress = '';
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fabController;
  late AnimationController _searchAnimationController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeLocation();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _fabController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: AnimationConstants.fastDuration,
      vsync: this,
    );

    // Start animations
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) {
        _slideController.forward();
        _searchAnimationController.forward();
      }
    });

    Future.delayed(AnimationConstants.extraLongDelay, () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fabController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeLocation() {
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _updateMarker(_selectedLocation);
    }
    if (widget.initialAddress != null) {
      _selectedAddress = widget.initialAddress!;
      _searchController.text = _selectedAddress;
    }

    _getCurrentLocationOptional();
  }

  // Improved location_picker_screen.dart methods
  // Replace the build method and overlay methods

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      resizeToAvoidBottomInset:
          false, // Prevent keyboard from resizing the entire screen
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: Stack(
          children: [
            // Google Map
            Positioned.fill(
              child: SlideInAnimation(
                delay: AnimationConstants.microDelay,
                child: _buildMap(),
              ),
            ),

            // Search Bar Overlay
            _buildSearchBarOverlay(),

            // Current Location FAB - Better positioned
            _buildLocationFAB(),

            // Address Display Bottom Sheet - Keyboard aware
            _buildKeyboardAwareBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBarOverlay() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: SlideInAnimation(
        beginOffset: AnimationConstants.slideFromTop,
        delay: AnimationConstants.shortDelay,
        child: ModernCard(
          padding: EdgeInsets.zero,
          enableGlassmorphism: true,
          child: GooglePlaceAutoCompleteTextField(
            textEditingController: _searchController,
            googleAPIKey: ApiKeys.googlePlacesApiKey,
            inputDecoration: InputDecoration(
              labelText: 'Search for location',
              hintText: 'Enter address, landmark, or area',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryEmerald,
                  size: 20,
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            debounceTime: 600,
            countries: ["lk"],
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (Prediction prediction) {
              if (prediction.lat != null && prediction.lng != null) {
                final location = LatLng(
                  double.parse(prediction.lat!),
                  double.parse(prediction.lng!),
                );
                _moveToLocation(location, prediction.description ?? '');
              }
            },
            itemClick: (Prediction prediction) {
              _searchController.text = prediction.description ?? '';
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLocationFAB() {
    return Positioned(
      top: 120, // Positioned below search bar instead of bottom
      right: 20,
      child: ScaleInAnimation(
        delay: AnimationConstants.extraLongDelay,
        child: Container(
          decoration: BoxDecoration(
            gradient: _isLoadingLocation
                ? LinearGradient(
                    colors: [AppTheme.textSecondary, AppTheme.borderMedium],
                  )
                : LinearGradient(
                    colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (_isLoadingLocation
                            ? AppTheme.textSecondary
                            : AppTheme.infoBlue)
                        .withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoadingLocation ? null : _getCurrentLocationOptional,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _isLoadingLocation
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardAwareBottomSheet() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    if (isKeyboardOpen) {
      return _buildFloatingMiniCard();
    } else {
      return _buildFullBottomSheet();
    }
  }

  Widget _buildFloatingMiniCard() {
    return Positioned(
      top: 180, // Position below search bar and FAB
      left: 20,
      right: 20,
      child: SlideInAnimation(
        beginOffset: const Offset(0, -30),
        delay: const Duration(milliseconds: 100),
        child: ModernCard(
          padding: EdgeInsets.zero,
          enableGlassmorphism: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Location icon with gradient background
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),

                // Address text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedAddress.isEmpty
                            ? 'No location selected'
                            : 'Selected Location',
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (_selectedAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _selectedAddress,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Action buttons
                if (_selectedAddress.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  // Expand button
                  GestureDetector(
                    onTap: () {
                      // Dismiss keyboard and show full bottom sheet
                      FocusScope.of(context).unfocus();
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _showLocationDetailsModal();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSecondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Confirm button
                  GestureDetector(
                    onTap: _confirmLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryEmerald.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Confirm',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Hint when no location selected
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tap map',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideInAnimation(
        beginOffset: AnimationConstants.slideFromBottom,
        delay: AnimationConstants.longDelay,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: ModernCard(
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Selected Location',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isLoadingAddress) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryEmerald,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Address container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAddress.isEmpty
                                  ? 'Tap on map or search to select location'
                                  : _selectedAddress,
                              style: AppTheme.bodyLarge.copyWith(
                                color: _selectedAddress.isEmpty
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                                fontWeight: _selectedAddress.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                              ),
                            ),
                            if (_selectedAddress.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, '
                                'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      ModernGradientButton(
                        text: 'Confirm',
                        onPressed: _selectedAddress.isNotEmpty
                            ? _confirmLocation
                            : null,
                        icon: Icons.check_circle_rounded,
                        gradient: AppTheme.primaryGradient,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modal for showing full details when expanding from mini card
  void _showLocationDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 100,
        ),
        child: ModernCard(
          borderRadius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Location Details',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full address display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundPrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.borderLight,
                            width: 1,
                          ),
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
                                Text(
                                  'Address',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedAddress.isEmpty
                                  ? 'No address available'
                                  : _selectedAddress,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 16,
                                  color: AppTheme.primaryTeal,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Coordinates',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}\n'
                              'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ModernGradientButton(
                              text: 'Edit',
                              onPressed: () {
                                Navigator.pop(context);
                                // Focus back on search or map
                              },
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.textSecondary,
                                  const Color.fromARGB(255, 121, 122, 124),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ModernGradientButton(
                              text: 'Confirm',
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmLocation();
                              },
                              gradient: AppTheme.primaryGradient,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      elevation: 8,
      shadowColor: AppTheme.primaryTeal.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryEmerald.withOpacity(0.2),
              AppTheme.primaryTeal.withOpacity(0.15),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryEmerald.withOpacity(0.2),
                    AppTheme.primaryTeal.withOpacity(0.15),
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
                      colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_searching_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.title,
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.only(
              left: 72,
              bottom: 16,
              right: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _selectedLocation,
        zoom: 16.0,
      ),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _updateMarker(_selectedLocation);
      },
      onTap: (LatLng location) {
        FocusScope.of(context).unfocus();
        _selectLocation(location);
      },
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      compassEnabled: true,
      buildingsEnabled: true,
      trafficEnabled: false,
      style: '''
        [
          {
            "featureType": "all",
            "stylers": [
              {
                "saturation": -20
              }
            ]
          }
        ]
      ''',
    );
  }

  // Core functionality methods
  void _selectLocation(LatLng location) async {
    setState(() {
      _selectedLocation = location;
      _isLoadingAddress = true;
    });

    _updateMarker(location);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16.0));

    await _getAddressFromCoordinates(location);
  }

  void _updateMarker(LatLng location) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          draggable: true,
          onDragEnd: (LatLng newLocation) {
            _selectLocation(newLocation);
          },
          infoWindow: const InfoWindow(
            title: 'Selected Location',
            snippet: 'Drag to adjust position',
          ),
        ),
      };
    });
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _selectedAddress = address;
          _searchController.text = address;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _selectedAddress = 'Location selected on map';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _moveToLocation(LatLng location, String address) {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = address;
      _searchController.text = address;
    });

    _updateMarker(location);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16.0));
  }

  Future<void> _getCurrentLocationOptional() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final location = LatLng(position.latitude, position.longitude);
      _moveToLocation(location, 'Current location');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Found your current location'),
            ],
          ),
          backgroundColor: AppTheme.primaryEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      print('GPS location failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                'Unable to get current location. You can still select manually.',
              ),
            ],
          ),
          backgroundColor: AppTheme.warningAmber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: AppTheme.warningAmber,
              ),
            ),
            const SizedBox(width: 12),
            Text('Location Permission'),
          ],
        ),
        content: Text(
          'Location permission helps find your current position. You can still select any location manually on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue Without GPS',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ModernGradientButton(
            text: 'Open Settings',
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'location': _selectedLocation,
      'address': _selectedAddress,
    });
  }
}
