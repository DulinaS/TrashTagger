// lib/screens/map/map_screen.dart - Fixed Overflow Issues
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trash_tagger/screens/map/report_detail_screen.dart';
import 'package:trash_tagger/screens/map/trash_map_view_screen.dart';
import '../../themes/app_theme.dart';
import '../../models/trash_report_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../animations/custom_animations.dart';
import '../../animations/page_transitions.dart';
import '../../animations/animation_constants.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  List<TrashReportModel> _nearbyReports = [];
  bool _isLoading = true;
  Position? _currentPosition;
  String _selectedFilter = 'all';

  late AnimationController _refreshController;
  late AnimationController _filterController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _filterController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _loadNearbyReports();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyReports() async {
    setState(() => _isLoading = true);

    try {
      await _getCurrentLocation();

      Query query = FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', whereIn: ['verified', 'cleaning'])
          .orderBy('timestamp', descending: true)
          .limit(50);

      final snapshot = await query.get();

      List<TrashReportModel> allReports = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }),
          )
          .toList();

      if (_currentPosition != null) {
        _nearbyReports = allReports.where((report) {
          double distance =
              Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                report.location.latitude,
                report.location.longitude,
              ) /
              1000;

          return distance <= 50;
        }).toList();
      } else {
        _nearbyReports = allReports;
      }

      if (_currentPosition != null) {
        _nearbyReports.sort((a, b) {
          double distanceA = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a.location.latitude,
            a.location.longitude,
          );
          double distanceB = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b.location.latitude,
            b.location.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
      }
    } catch (e) {
      print('Error loading nearby reports: $e');
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  List<TrashReportModel> get _filteredReports {
    if (_selectedFilter == 'all') return _nearbyReports;
    return _nearbyReports
        .where((report) => report.trashType == _selectedFilter)
        .toList();
  }

  void _navigateToMapView() {
    Navigator.push(
      context,
      PageTransitions.slideAndFade(
        page: const TrashMapViewScreen(),
        duration: AnimationConstants.mediumDuration,
        beginOffset: const Offset(0.0, 1.0),
      ),
    );
  }

  Future<void> _refreshReports() async {
    _refreshController.forward().then((_) {
      _refreshController.reset();
    });
    await _loadNearbyReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Location Status and Stats
                SlideInAnimation(
                  delay: AnimationConstants.shortDelay,
                  child: _buildLocationHeader(),
                ),

                // Filter Section
                SlideInAnimation(
                  beginOffset: const Offset(0, -0.3),
                  duration: AnimationConstants.slowDuration,
                  curve: AnimationConstants.bounceCurve,
                  child: _buildFilterSection(),
                ),
              ],
            ),
          ),

          // Reports List
          _isLoading
              ? SliverToBoxAdapter(
                  child: const LoadingWidget(
                    message: 'Loading nearby reports...',
                  ),
                )
              : _buildReportsSliver(),
        ],
      ),
      floatingActionButton: AnimatedFAB(
        onPressed: _navigateToMapView,
        heroTag: "mapViewFAB",
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        delay: AnimationConstants.longDelay,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded),
            const SizedBox(width: 8),
            Text(
              'Map View',
              style: AppTheme.labelMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
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
                  colors: [AppTheme.primaryTeal, AppTheme.accentPurple],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Nearby Reports',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
            onPressed: _refreshReports,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryEmerald.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _currentPosition != null
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPosition != null
                          ? 'Location Found'
                          : 'Location Not Available',
                      style: AppTheme.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _currentPosition != null
                          ? 'Showing reports within 50km'
                          : 'Showing all available reports',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredReports.length} found',
                  style: AppTheme.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Type',
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: StaggeredListAnimation(
              direction: Axis.horizontal,
              itemDelay: const Duration(
                milliseconds: AnimationConstants.staggerDelayMs,
              ),
              beginOffset: const Offset(0.3, 0),
              children: [
                _buildFilterChip('all', 'All', Icons.view_list_rounded),
                _buildFilterChip('general', 'General', Icons.delete_rounded),
                _buildFilterChip(
                  'recyclable',
                  'Recyclable',
                  Icons.recycling_rounded,
                ),
                _buildFilterChip(
                  'hazardous',
                  'Hazardous',
                  Icons.warning_rounded,
                ),
                _buildFilterChip('large', 'Large Items', Icons.chair_rounded),
                _buildFilterChip('organic', 'Organic', Icons.eco_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    final count = value == 'all'
        ? _nearbyReports.length
        : _nearbyReports.where((r) => r.trashType == value).length;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: AnimatedContainer(
        duration: AnimationConstants.fastDuration,
        curve: AnimationConstants.smoothCurve,
        child: FilterChip(
          avatar: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : AppTheme.primaryEmerald,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: AnimationConstants.fastDuration,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.primaryEmerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: AppTheme.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.primaryEmerald,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedFilter = value);
            _filterController.forward().then((_) {
              _filterController.reset();
            });
          },
          selectedColor: AppTheme.primaryEmerald,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.primaryEmerald,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsSliver() {
    final reports = _filteredReports;

    if (reports.isEmpty) {
      return SliverToBoxAdapter(
        child: SlideInAnimation(
          beginOffset: const Offset(0, 0.3),
          delay: AnimationConstants.shortDelay,
          child: _buildEmptyState(),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return SlideInAnimation(
          duration: AnimationConstants.mediumDuration,
          delay: Duration(
            milliseconds: index * AnimationConstants.cardStaggerDelayMs,
          ),
          beginOffset: const Offset(0.3, 0),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              index == 0 ? 16 : 8,
              20,
              index == reports.length - 1 ? 120 : 8,
            ),
            child: _buildModernReportCard(reports[index], index),
          ),
        );
      }, childCount: reports.length),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleInAnimation(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryEmerald.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SlideInAnimation(
              beginOffset: const Offset(0, 0.2),
              delay: const Duration(milliseconds: 200),
              child: Text(
                _selectedFilter == 'all'
                    ? 'No Reports Nearby'
                    : 'No ${Helpers.getTrashTypeDisplayName(_selectedFilter)} Reports',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              beginOffset: const Offset(0, 0.2),
              delay: const Duration(milliseconds: 300),
              child: Text(
                _currentPosition == null
                    ? 'Enable location to see nearby reports'
                    : 'Be the first to report trash in your area!',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (_currentPosition == null) ...[
              const SizedBox(height: 32),
              ScaleInAnimation(
                delay: const Duration(milliseconds: 400),
                child: ElevatedButton.icon(
                  onPressed: _refreshReports,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Enable Location',
                    style: AppTheme.labelLarge.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ScaleInAnimation(
              delay: const Duration(milliseconds: 500),
              child: OutlinedButton.icon(
                onPressed: _navigateToMapView,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primaryEmerald),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.map_rounded, color: AppTheme.primaryEmerald),
                label: Text(
                  'View on Map',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.primaryEmerald,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernReportCard(TrashReportModel report, int index) {
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
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToReportDetail(report),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Type Icon with pulse animation
                    PulseAnimation(
                      duration: const Duration(seconds: 2),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppTheme.getSeverityGradient(
                            report.severity,
                          ),
                          borderRadius: BorderRadius.circular(16),
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
                    ),
                    const SizedBox(width: 16),

                    // Report Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Helpers.getTrashTypeDisplayName(report.trashType),
                            style: AppTheme.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    report.status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusDisplayName(report.status),
                                  style: AppTheme.labelSmall.copyWith(
                                    color: _getStatusColor(report.status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.getSeverityColor(
                                    report.severity,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${report.severity.toUpperCase()} PRIORITY',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.getSeverityColor(
                                      report.severity,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Arrow with bounce animation
                    SlideInAnimation(
                      duration: AnimationConstants.mediumDuration,
                      delay: Duration(
                        milliseconds:
                            300 +
                            (index * AnimationConstants.cardStaggerDelayMs),
                      ),
                      beginOffset: const Offset(0.3, 0),
                      curve: AnimationConstants.bounceCurve,
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Location and Details - FIXED OVERFLOW HERE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppTheme.primaryEmerald,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.address,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // FIXED ROW - Made responsive with Flexible widgets
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // For very small screens, stack vertically
                          if (constraints.maxWidth < 300) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (distance != null)
                                  _buildInfoItem(
                                    icon: Icons.near_me_rounded,
                                    text: Helpers.formatDistance(distance),
                                  ),
                                const SizedBox(height: 4),
                                _buildInfoItem(
                                  icon: Icons.access_time_rounded,
                                  text: Helpers.formatDateTime(
                                    report.timestamp,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildInfoItem(
                                  icon: Icons.timer_outlined,
                                  text: report.estimatedEffort,
                                ),
                              ],
                            );
                          }

                          // For larger screens, use flexible row
                          return Row(
                            children: [
                              if (distance != null) ...[
                                Flexible(
                                  child: _buildInfoItem(
                                    icon: Icons.near_me_rounded,
                                    text: Helpers.formatDistance(distance),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: _buildInfoItem(
                                  icon: Icons.access_time_rounded,
                                  text: Helpers.formatDateTime(
                                    report.timestamp,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: _buildInfoItem(
                                  icon: Icons.timer_outlined,
                                  text: report.estimatedEffort,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Safety Warnings with animation
                if (report.safetyWarnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SlideInAnimation(
                    beginOffset: const Offset(0, 0.1),
                    delay: Duration(
                      milliseconds:
                          200 + (index * AnimationConstants.cardStaggerDelayMs),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warningAmber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          PulseAnimation(
                            duration: const Duration(seconds: 3),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: AppTheme.warningAmber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.safetyWarnings.first,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.warningAmber,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

  // Helper widget for info items
  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  void _navigateToReportDetail(TrashReportModel report) {
    Navigator.push(
      context,
      PageTransitions.slideFromRight(
        page: ReportDetailScreen(report: report),
        duration: AnimationConstants.mediumDuration,
      ),
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
        return Icons.help_rounded;
    }
  }

  Color _getStatusColor(String status) {
    return AppTheme.getStatusColor(status);
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
