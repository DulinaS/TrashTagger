// lib/screens/map/trash_map_view_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../themes/app_theme.dart';
import '../../models/trash_report_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/modern/modern_widgets.dart';
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

  // Animation controllers
  late AnimationController _bottomSheetController;
  late AnimationController _fabController;
  late AnimationController _refreshController;
  late Animation<double> _bottomSheetAnimation;
  late Animation<double> _fabAnimation;

  // Map bounds for fitting markers
  LatLng _defaultCenter = const LatLng(6.9271, 79.8612); // Colombo default

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadReportsAndLocation();
  }

  void _initializeAnimations() {
    _bottomSheetController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _fabController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: AnimationConstants.refreshDuration,
      vsync: this,
    );

    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: AnimationConstants.modernCurve,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: AnimationConstants.bounceCurve,
    );

    // Start FAB animation after delay
    Future.delayed(AnimationConstants.extraLongDelay, () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void dispose() {
    _bottomSheetController.dispose();
    _fabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadReportsAndLocation() async {
    setState(() => _isLoading = true);

    try {
      await _getCurrentLocation();
      await _loadReports();
      await _createMarkers();
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to load map data: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
        AppTheme.getSeverityColor(report.severity),
        50,
      );

      markers.add(
        Marker(
          markerId: MarkerId('report_${report.id}'),
          position: LatLng(report.location.latitude, report.location.longitude),
          icon: markerIcon,
          onTap: () => _selectReport(report),
          infoWindow: InfoWindow(
            title: Helpers.getTrashTypeDisplayName(report.trashType),
            snippet: _getStatusDisplayName(report.status),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    IconData iconData,
    Color color,
    double size,
  ) async {
    // Enhanced marker colors based on modern theme
    if (color == AppTheme.errorRed) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (color == AppTheme.warningAmber) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else if (color == AppTheme.infoBlue) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } else if (color == AppTheme.primaryTeal) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
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

    _bottomSheetController.forward();

    // Move camera to selected report with smooth animation
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(report.location.latitude, report.location.longitude),
        17.0,
      ),
    );
  }

  void _closeBottomSheet() {
    _bottomSheetController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedReport = null;
        });
      }
    });
  }

  Future<void> _refreshData() async {
    _refreshController.forward().then((_) {
      _refreshController.reset();
    });
    await _loadReportsAndLocation();
  }

  Future<void> _openGoogleMapsRoute(LatLng destination) async {
    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Current location not available'),
              ],
            ),
            backgroundColor: AppTheme.warningAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Could not open Google Maps'),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: _isLoading
          ? const ModernLoadingWidget(message: 'Loading map...')
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
                  ''', // Subtle map styling
                ),

                // Modern App Bar
                _buildModernAppBar(),

                // Filter Section
                SlideInAnimation(
                  beginOffset: AnimationConstants.slideFromTop,
                  delay: AnimationConstants.shortDelay,
                  child: _buildFilterSection(),
                ),

                // Stats Card
                SlideInAnimation(
                  beginOffset: const Offset(-0.3, 0),
                  delay: AnimationConstants.mediumDelay,
                  child: _buildStatsCard(),
                ),

                // Modern FAB Controls
                _buildFABControls(),

                // Bottom Sheet for Selected Report
                if (_selectedReport != null)
                  AnimatedBuilder(
                    animation: _bottomSheetAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          320 * (1 - _bottomSheetAnimation.value),
                        ),
                        child: _buildSelectedReportSheet(),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildModernAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 20,
          right: 20,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundSecondary,
              AppTheme.backgroundSecondary.withOpacity(0.9),
              AppTheme.backgroundSecondary.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowLight,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.map_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Trash Map',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final filterOptions = [
      {
        'value': 'all',
        'label': 'All',
        'icon': Icons.view_list_rounded,
        'count': _reports.length,
        'gradient': AppTheme.primaryGradient,
      },
      {
        'value': 'general',
        'label': 'General',
        'icon': Icons.delete_rounded,
        'count': _reports.where((r) => r.trashType == 'general').length,
        'gradient': LinearGradient(
          colors: [AppTheme.textSecondary, AppTheme.borderMedium],
        ),
      },
      {
        'value': 'recyclable',
        'label': 'Recyclable',
        'icon': Icons.recycling_rounded,
        'count': _reports.where((r) => r.trashType == 'recyclable').length,
        'gradient': LinearGradient(
          colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
        ),
      },
      {
        'value': 'hazardous',
        'label': 'Hazardous',
        'icon': Icons.warning_rounded,
        'count': _reports.where((r) => r.trashType == 'hazardous').length,
        'gradient': AppTheme.errorGradient,
      },
      {
        'value': 'large',
        'label': 'Large',
        'icon': Icons.chair_rounded,
        'count': _reports.where((r) => r.trashType == 'large').length,
        'gradient': LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentCoral],
        ),
      },
      {
        'value': 'organic',
        'label': 'Organic',
        'icon': Icons.eco_rounded,
        'count': _reports.where((r) => r.trashType == 'organic').length,
        'gradient': AppTheme.successGradient,
      },
    ];

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: filterOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              return ScaleInAnimation(
                delay: Duration(milliseconds: 100 + (index * 50)),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildModernFilterChip(
                    option['value'] as String,
                    option['label'] as String,
                    option['icon'] as IconData,
                    option['count'] as int,
                    option['gradient'] as LinearGradient,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFilterChip(
    String value,
    String label,
    IconData icon,
    int count,
    LinearGradient gradient,
  ) {
    final isSelected = _selectedFilter == value;

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedFilter = value);
        await _createMarkers();
      },
      child: AnimatedContainer(
        duration: AnimationConstants.fastDuration,
        curve: AnimationConstants.modernCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? gradient.colors.first : AppTheme.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppTheme.shadowLight,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : gradient.colors.first,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color: isSelected ? Colors.white : gradient.colors.first,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : gradient.colors.first.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: AppTheme.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : gradient.colors.first,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final filteredCount = _filteredReports.length;
    return Positioned(
      top: 200,
      left: 20,
      child: ModernCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enableGlassmorphism: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$filteredCount',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
                Text(
                  'Report${filteredCount != 1 ? 's' : ''}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFABControls() {
    return Positioned(
      bottom: 100,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // My Location FAB
          ScaleInAnimation(
            delay: AnimationConstants.longDelay,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.infoBlue.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _centerOnUserLocation,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Refresh FAB
          ScaleInAnimation(
            delay: const Duration(milliseconds: 600),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryEmerald.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _refreshData,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
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

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ModernCard(
        margin: const EdgeInsets.all(20),
        borderRadius: 24,
        enableGlassmorphism: false,
        backgroundColor: AppTheme.backgroundSecondary,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowHeavy,
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
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
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: AppTheme.getSeverityGradient(
                            report.severity,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getSeverityColor(
                                report.severity,
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getTrashTypeIcon(report.trashType),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Helpers.getTrashTypeDisplayName(report.trashType),
                              style: AppTheme.headlineMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ModernStatusBadge(
                                  status: report.status,
                                  showPulse: report.status == 'cleaning',
                                ),
                                if (distance != null) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 12,
                                          color: AppTheme.infoBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          Helpers.formatDistance(distance),
                                          style: AppTheme.labelSmall.copyWith(
                                            color: AppTheme.infoBlue,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundPrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: IconButton(
                          onPressed: _closeBottomSheet,
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 20,
                          color: AppTheme.primaryEmerald,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            report.address,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ModernGradientButton(
                          text: 'View Details',
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageTransitions.slideFromRight(
                                page: ReportDetailScreen(report: report),
                              ),
                            );
                          },
                          icon: Icons.info_outline_rounded,
                          isOutlined: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ModernGradientButton(
                          text: 'Directions',
                          onPressed: () => _openGoogleMapsRoute(
                            LatLng(
                              report.location.latitude,
                              report.location.longitude,
                            ),
                          ),
                          icon: Icons.directions_rounded,
                          gradient: AppTheme.primaryGradient,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Location not available'),
            ],
          ),
          backgroundColor: AppTheme.warningAmber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
    if (list.isEmpty) {
      return LatLngBounds(southwest: _defaultCenter, northeast: _defaultCenter);
    }

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

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'verified':
        return 'Available for Cleanup';
      case 'cleaning':
        return 'Cleanup in Progress';
      case 'completed':
        return 'Cleanup Completed';
      default:
        return status;
    }
  }
}
