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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: Stack(
          children: [
            // Google Map
            SlideInAnimation(
              delay: AnimationConstants.microDelay,
              child: _buildMap(),
            ),

            // Search Bar Overlay
            SlideInAnimation(
              beginOffset: AnimationConstants.slideFromTop,
              delay: AnimationConstants.shortDelay,
              child: _buildSearchBarOverlay(),
            ),

            // Quick Locations
            SlideInAnimation(
              beginOffset: const Offset(-0.3, 0),
              delay: AnimationConstants.mediumDelay,
              child: _buildQuickLocationsOverlay(),
            ),

            // Address Display Bottom Sheet
            SlideInAnimation(
              beginOffset: AnimationConstants.slideFromBottom,
              delay: AnimationConstants.longDelay,
              child: _buildAddressBottomSheet(),
            ),

            // FAB for current location
            ScaleInAnimation(
              delay: AnimationConstants.extraLongDelay,
              child: _buildLocationFAB(),
            ),
          ],
        ),
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
                AppTheme.primaryTeal.withOpacity(0.05),
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
            Text(
              widget.title,
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
    );
  }

  Widget _buildSearchBarOverlay() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
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
    );
  }

  Widget _buildQuickLocationsOverlay() {
    final quickLocations = [
      {
        'name': 'Galle Face',
        'location': LatLng(6.9246, 79.8442),
        'icon': Icons.beach_access_rounded,
        'gradient': AppTheme.primaryGradient,
      },
      {
        'name': 'Viharamahadevi Park',
        'location': LatLng(6.9147, 79.8610),
        'icon': Icons.park_rounded,
        'gradient': AppTheme.successGradient,
      },
      {
        'name': 'Colombo Fort',
        'location': LatLng(6.9344, 79.8428),
        'icon': Icons.location_city_rounded,
        'gradient': LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        ),
      },
      {
        'name': 'Mount Lavinia',
        'location': LatLng(6.8344, 79.8631),
        'icon': Icons.waves_rounded,
        'gradient': LinearGradient(
          colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
        ),
      },
    ];

    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: quickLocations.length,
          itemBuilder: (context, index) {
            final location = quickLocations[index];

            return ScaleInAnimation(
              delay: Duration(milliseconds: 100 + (index * 50)),
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                child: ModernCard(
                  onTap: () {
                    _moveToLocation(
                      location['location'] as LatLng,
                      location['name'] as String,
                    );
                  },
                  padding: const EdgeInsets.all(12),
                  enableGlassmorphism: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: location['gradient'] as LinearGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          location['icon'] as IconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        location['name'] as String,
                        style: AppTheme.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

  Widget _buildAddressBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ModernCard(
        margin: const EdgeInsets.all(20),
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
                      Text(
                        'Selected Location',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
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
                    text: 'Confirm Location',
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
    );
  }

  Widget _buildLocationFAB() {
    return Positioned(
      bottom: 200,
      right: 20,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
