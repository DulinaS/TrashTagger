// lib/screens/location/location_picker_screen.dart - CREATE NEW FILE
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/api_keys.dart';
import '../../themes/app_theme.dart';
import '../../utils/helpers.dart';

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

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(6.9271, 79.8612); // Default: Colombo
  String _selectedAddress = '';
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
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

    // Try to get user's current location as starting point (optional)
    _getCurrentLocationOptional();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocationOptional,
            tooltip: 'Use my location',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildQuickLocations(),
          Expanded(child: _buildMap()),
          _buildAddressDisplay(),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: _searchController,
        googleAPIKey: ApiKeys.googlePlacesApiKey,
        inputDecoration: InputDecoration(
          labelText: 'Search for location',
          hintText: 'Enter address, landmark, or area',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        debounceTime: 600,
        countries: ["lk"], // Adjust for your region
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
    );
  }

  Widget _buildQuickLocations() {
    final quickLocations = [
      {'name': 'Galle Face Green', 'location': LatLng(6.9246, 79.8442)},
      {'name': 'Viharamahadevi Park', 'location': LatLng(6.9147, 79.8610)},
      {'name': 'Colombo Fort', 'location': LatLng(6.9344, 79.8428)},
      {'name': 'Mount Lavinia Beach', 'location': LatLng(6.8344, 79.8631)},
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: quickLocations.length,
        itemBuilder: (context, index) {
          final location = quickLocations[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(location['name'] as String),
              onPressed: () {
                _moveToLocation(
                  location['location'] as LatLng,
                  location['name'] as String,
                );
              },
            ),
          );
        },
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
    );
  }

  Widget _buildAddressDisplay() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text('Selected Location', style: AppTheme.labelMedium),
              if (_isLoadingAddress) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          Text(
            _selectedAddress.isEmpty
                ? 'Tap on map or search to select location'
                : _selectedAddress,
            style: AppTheme.bodyMedium.copyWith(
              color: _selectedAddress.isEmpty
                  ? AppTheme.textSecondary
                  : AppTheme.textPrimary,
            ),
          ),

          if (_selectedAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, '
              'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
              style: AppTheme.bodyMedium.copyWith(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _selectedAddress.isNotEmpty ? _confirmLocation : null,
          icon: const Icon(Icons.check),
          label: const Text('Confirm Location'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
          content: Text('Found your current location'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      print('GPS location failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to get current location. You can still select manually.',
          ),
          backgroundColor: AppTheme.warningOrange,
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
        title: Text('Location Permission'),
        content: Text(
          'Location permission helps find your current position. You can still select any location manually on the map.',
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

  void _confirmLocation() {
    Navigator.pop(context, {
      'location': _selectedLocation,
      'address': _selectedAddress,
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
