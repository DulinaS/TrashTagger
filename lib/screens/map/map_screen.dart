// lib/screens/map/map_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trash_tagger/screens/map/report_detail_Screen.dart';
import '../../themes/app_theme.dart';
import '../../models/trash_report_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/loading_widget.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<TrashReportModel> _nearbyReports = [];
  bool _isLoading = true;
  Position? _currentPosition;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadNearbyReports();
  }

  Future<void> _loadNearbyReports() async {
    setState(() => _isLoading = true);

    try {
      // Get current location
      await _getCurrentLocation();

      // Load reports from Firestore
      Query query = FirebaseFirestore.instance
          .collection('trashReports')
          .where('status', whereIn: ['verified', 'cleaning'])
          .orderBy('timestamp', descending: true)
          .limit(50);

      final snapshot = await query.get();

      List<TrashReportModel> allReports = snapshot.docs
          .map(
            (doc) => TrashReportModel.fromMap({
              '_documentId': doc.id, // Use actual document ID
              ...doc.data() as Map<String, dynamic>,
            }),
          )
          .toList();

      // Filter by distance if location available
      if (_currentPosition != null) {
        _nearbyReports = allReports.where((report) {
          double distance =
              Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                report.location.latitude,
                report.location.longitude,
              ) /
              1000; // Convert to km

          return distance <= 50; // Within 50km
        }).toList();
      } else {
        _nearbyReports = allReports;
      }

      // Sort by distance if location available
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Nearby Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),

          // Reports List
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Loading nearby reports...')
                : _buildReportsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text('Filter by Type', style: AppTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All', Icons.view_list),
                _buildFilterChip('general', 'General', Icons.delete_outline),
                _buildFilterChip('recyclable', 'Recyclable', Icons.recycling),
                _buildFilterChip('hazardous', 'Hazardous', Icons.warning),
                _buildFilterChip('large', 'Large Items', Icons.chair),
                _buildFilterChip('organic', 'Organic', Icons.eco),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppTheme.primaryGreen,
        ),
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: AppTheme.primaryGreen,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.primaryGreen,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    final reports = _filteredReports;

    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 80, color: AppTheme.textSecondary),
              const SizedBox(height: 24),
              Text(
                _selectedFilter == 'all'
                    ? 'No Reports Nearby'
                    : 'No ${Helpers.getTrashTypeDisplayName(_selectedFilter)} Reports',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _currentPosition == null
                    ? 'Enable location to see nearby reports'
                    : 'Be the first to report trash in your area!',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_currentPosition == null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadNearbyReports,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Enable Location'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(TrashReportModel report) {
    final distance = _currentPosition != null
        ? Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                report.location.latitude,
                report.location.longitude,
              ) /
              1000
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToReportDetail(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Type Icon
                  Container(
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
                  const SizedBox(width: 12),

                  // Report Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              Helpers.getTrashTypeDisplayName(report.trashType),
                              style: AppTheme.labelMedium,
                            ),
                            const SizedBox(width: 8),
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
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.address,
                          style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (distance != null) ...[
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                Helpers.formatDistance(distance),
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Helpers.formatDateTime(report.timestamp),
                              style: AppTheme.bodyMedium.copyWith(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),

              // Effort and Safety Warnings
              if (report.safetyWarnings.isNotEmpty ||
                  report.estimatedEffort.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (report.estimatedEffort.isNotEmpty) ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.estimatedEffort,
                        style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ],
                    if (report.safetyWarnings.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Safety Warning',
                        style: AppTheme.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToReportDetail(TrashReportModel report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(report: report),
      ),
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
