// lib/screens/map/trash_map_view_screen.dart - UPDATED WITH REUSABLE ANIMATIONS
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../themes/app_theme.dart';
import '../../models/trash_report_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../animations/custom_animations.dart';
import '../../animations/page_transitions.dart';
import '../../animations/animation_constants.dart';
import 'report_detail_screen.dart';

class TrashMapViewScreen extends StatefulWidget {
  const TrashMapViewScreen({Key? key}) : super(key: key);

  @override
  _TrashMapViewScreenState createState() => _TrashMapViewScreenState();
}

class _TrashMapViewScreenState extends State<TrashMapViewScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  List<TrashReportModel> _reports = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;
  Position? _currentPosition;
  String _selectedFilter = 'all';
  TrashReportModel? _selectedReport;

  // Map bounds for fitting markers
  LatLng _defaultCenter = const LatLng(6.9271, 79.8612); // Colombo default

  @override
  void initState() {
    super.initState();
    _loadReportsAndLocation();
  }

  Future<void> _loadReportsAndLocation() async {
    setState(() => _isLoading = true);

    try {
      // Get current location first
      await _getCurrentLocation();

      // Load reports from Firestore
      await _loadReports();

      // Create markers
      await _createMarkers();
    } catch (e) {
      print('Error loading data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Permission.location.request();
      if (!permission.isGranted) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (_currentPosition != null) {
        _defaultCenter = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadReports() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', whereIn: ['verified', 'cleaning'])
          .orderBy('timestamp', descending: true)
          .limit(100);

      final snapshot = await query.get();

      _reports = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }),
          )
          .toList();

      // Filter nearby reports if location available
      if (_currentPosition != null) {
        _reports = _reports.where((report) {
          double distance =
              Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                report.location.latitude,
                report.location.longitude,
              ) /
              1000;
          return distance <= 50; // Within 50km
        }).toList();
      }
    } catch (e) {
      print('Error loading reports: $e');
    }
  }

  Future<void> _createMarkers() async {
    Set<Marker> markers = {};

    // Add user location marker if available
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: await _createCustomMarkerIcon(
            Icons.person_pin_circle,
            AppTheme.infoBlue,
            60,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add trash report markers
    for (var report in _filteredReports) {
      final markerIcon = await _createCustomMarkerIcon(
        _getTrashTypeIcon(report.trashType),
        Helpers.getSeverityColor(report.severity),
        50,
      );

      markers.add(
        Marker(
          markerId: MarkerId('report_${report.id}'),
          position: report.location,
          icon: markerIcon,
          onTap: () => _selectReport(report),
          infoWindow: InfoWindow(
            title: Helpers.getTrashTypeDisplayName(report.trashType),
            snippet: _getStatusDisplayName(report.status),
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    IconData iconData,
    Color color,
    double size,
  ) async {
    // For now, use default markers with different colors
    // You can implement custom marker creation here if needed
    if (color == AppTheme.dangerRed) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (color == AppTheme.warningOrange) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else if (color == AppTheme.infoBlue) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  List<TrashReportModel> get _filteredReports {
    if (_selectedFilter == 'all') return _reports;
    return _reports
        .where((report) => report.trashType == _selectedFilter)
        .toList();
  }

  void _selectReport(TrashReportModel report) {
    setState(() {
      _selectedReport = report;
    });

    // Move camera to selected report
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(report.location, 17.0),
    );
  }

  void _closeBottomSheet() {
    setState(() {
      _selectedReport = null;
    });
  }

  Future<void> _openGoogleMapsRoute(LatLng destination) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Current location not available'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    final url =
        'https://www.google.com/maps/dir/${_currentPosition!.latitude},${_currentPosition!.longitude}/${destination.latitude},${destination.longitude}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Trash Map'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUserLocation,
            tooltip: 'Center on my location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportsAndLocation,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading map...')
          : Stack(
              children: [
                // Google Maps
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _defaultCenter,
                    zoom: _currentPosition != null ? 14.0 : 12.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_markers.isNotEmpty) {
                      _fitMarkersInView();
                    }
                  },
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: (_) => _closeBottomSheet(),
                ),

                // Filter Section (Animated)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SlideInAnimation(
                    beginOffset: const Offset(0, -1),
                    duration: AnimationConstants.extraSlowDuration,
                    curve: AnimationConstants.bounceCurve,
                    child: _buildFilterSection(),
                  ),
                ),

                // Stats Card
                Positioned(
                  top: 120,
                  left: 16,
                  child: ScaleInAnimation(
                    delay: AnimationConstants.mediumDelay,
                    child: _buildStatsCard(),
                  ),
                ),

                // Bottom Sheet for Selected Report
                if (_selectedReport != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SlideUpBottomSheet(
                      isVisible: _selectedReport != null,
                      onDismiss: _closeBottomSheet,
                      child: _buildSelectedReportSheet(),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: StaggeredListAnimation(
          direction: Axis.horizontal,
          itemDelay: const Duration(
            milliseconds: AnimationConstants.staggerDelayMs,
          ),
          beginOffset: const Offset(0.3, 0),
          children: [
            _buildFilterChip('all', 'All', Icons.view_list, _reports.length),
            _buildFilterChip(
              'general',
              'General',
              Icons.delete_outline,
              _reports.where((r) => r.trashType == 'general').length,
            ),
            _buildFilterChip(
              'recyclable',
              'Recyclable',
              Icons.recycling,
              _reports.where((r) => r.trashType == 'recyclable').length,
            ),
            _buildFilterChip(
              'hazardous',
              'Hazardous',
              Icons.warning,
              _reports.where((r) => r.trashType == 'hazardous').length,
            ),
            _buildFilterChip(
              'large',
              'Large',
              Icons.chair,
              _reports.where((r) => r.trashType == 'large').length,
            ),
            _buildFilterChip(
              'organic',
              'Organic',
              Icons.eco,
              _reports.where((r) => r.trashType == 'organic').length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String value,
    String label,
    IconData icon,
    int count,
  ) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: AnimationConstants.fastDuration,
        curve: AnimationConstants.smoothCurve,
        child: FilterChip(
          avatar: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : AppTheme.primaryGreen,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: AnimationConstants.fastDuration,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) async {
            setState(() => _selectedFilter = value);
            await _createMarkers();
          },
          selectedColor: AppTheme.primaryGreen,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.primaryGreen,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final filteredCount = _filteredReports.length;
    return AnimatedContainer(
      duration: AnimationConstants.mediumDuration,
      curve: AnimationConstants.smoothCurve,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseAnimation(
            child: Icon(
              Icons.location_on,
              size: 16,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$filteredCount Report${filteredCount != 1 ? 's' : ''}',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedReportSheet() {
    if (_selectedReport == null) return const SizedBox.shrink();

    final report = _selectedReport!;
    final distance = _currentPosition != null
        ? Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                report.location.latitude,
                report.location.longitude,
              ) /
              1000
        : null;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ScaleInAnimation(
                        duration: AnimationConstants.mediumDuration,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Helpers.getSeverityColor(
                              report.severity,
                            ).withOpacity(0.1),
                          ),
                          child: Icon(
                            _getTrashTypeIcon(report.trashType),
                            color: Helpers.getSeverityColor(report.severity),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SlideInAnimation(
                          beginOffset: const Offset(0.3, 0),
                          delay: const Duration(milliseconds: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Helpers.getTrashTypeDisplayName(
                                  report.trashType,
                                ),
                                style: AppTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        report.status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusDisplayName(report.status),
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: _getStatusColor(report.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (distance != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      Helpers.formatDistance(distance),
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _closeBottomSheet,
                        icon: Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SlideInAnimation(
                    beginOffset: const Offset(0, 0.2),
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      report.address,
                      style: AppTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SlideInAnimation(
                    beginOffset: const Offset(0, 0.3),
                    delay: const Duration(milliseconds: 300),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageTransitions.slideFromRight(
                                  page: ReportDetailScreen(report: report),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('View Details'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _openGoogleMapsRoute(report.location),
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Get Directions'),
                          ),
                        ),
                      ],
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

  void _centerOnUserLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16.0,
        ),
      );
    }
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    LatLngBounds bounds = _boundsFromLatLngList(
      _markers.map((marker) => marker.position).toList(),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;

    for (LatLng latLng in list) {
      minLat = minLat > latLng.latitude ? latLng.latitude : minLat;
      maxLat = maxLat < latLng.latitude ? latLng.latitude : maxLat;
      minLng = minLng > latLng.longitude ? latLng.longitude : minLng;
      maxLng = maxLng < latLng.longitude ? latLng.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
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
        return 'Available';
      case 'cleaning':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
