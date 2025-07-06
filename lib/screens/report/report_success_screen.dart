// lib/screens/report/report_success_screen.dart
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/custom_button.dart';

class ReportSuccessScreen extends StatelessWidget {
  final String reportId;

  const ReportSuccessScreen({Key? key, required this.reportId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success Animation/Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        border: Border.all(
                          color: AppTheme.primaryGreen,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 40,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Success Title
                    Text(
                      'Report Submitted!',
                      style: AppTheme.headlineLarge.copyWith(
                        color: AppTheme.primaryGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Success Message
                    Text(
                      'Thank you for helping clean up our community! Your report is being analyzed by our AI system.',
                      style: AppTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Info Cards
                    _buildInfoCard('What happens next?', [
                      '🤖 AI analyzes your photo for verification',
                      '✅ Report becomes available as a cleanup challenge',
                      '👥 Community members can accept the challenge',
                      '🏆 You earn points when it\'s completed!',
                    ]),
                    const SizedBox(height: 20),

                    _buildInfoCard('Your Impact', [
                      '🌱 You\'ve taken the first step to clean up trash',
                      '📍 Your location data helps identify problem areas',
                      '🎯 Every report brings us closer to a cleaner world',
                    ]),
                    const SizedBox(height: 20),

                    // Report ID (for reference)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Report ID',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reportId.length > 12
                                ? '${reportId.substring(0, 12)}...'
                                : reportId,
                            style: AppTheme.bodyMedium.copyWith(
                              fontFamily: 'monospace',
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Column(
                children: [
                  CustomButton(
                    text: 'Report More Trash',
                    onPressed: () => _reportMore(context),
                    icon: Icons.camera_alt,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Find Cleanup Challenges',
                    onPressed: () => _findChallenges(context),
                    isOutlined: true,
                    icon: Icons.search,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Back to Home',
                    onPressed: () => _goHome(context),
                    isOutlined: true,
                    backgroundColor: AppTheme.textSecondary,
                    icon: Icons.home,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.headlineMedium.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(item, style: AppTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reportMore(BuildContext context) {
    // Navigate back to camera, but clear the stack to avoid building up
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Navigate to camera tab
    // This assumes your bottom navigation can handle index switching
  }

  void _findChallenges(BuildContext context) {
    // Navigate to challenges tab
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Switch to challenges tab (index 3)
  }

  void _goHome(BuildContext context) {
    // Pop all the way back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
