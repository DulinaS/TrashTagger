// lib/screens/report/report_success_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class ReportSuccessScreen extends StatefulWidget {
  final String reportId;

  const ReportSuccessScreen({Key? key, required this.reportId})
    : super(key: key);

  @override
  _ReportSuccessScreenState createState() => _ReportSuccessScreenState();
}

class _ReportSuccessScreenState extends State<ReportSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late AnimationController _contentController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      duration: AnimationConstants.extraSlowDuration,
      vsync: this,
    );
    _contentController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    // Start celebrations
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) {
        _celebrationController.forward();
        _contentController.forward();
      }
    });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryEmerald.withOpacity(0.1),
              AppTheme.successGreen.withOpacity(0.05),
              AppTheme.backgroundPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        // Success Animation/Icon
                        ScaleInAnimation(
                          delay: AnimationConstants.microDelay,
                          curve: AnimationConstants.bounceCurve,
                          child: _buildSuccessIcon(),
                        ),
                        const SizedBox(height: 40),

                        // Success Title
                        SlideInAnimation(
                          delay: AnimationConstants.shortDelay,
                          child: _buildSuccessTitle(),
                        ),
                        const SizedBox(height: 20),

                        // Success Message
                        SlideInAnimation(
                          delay: AnimationConstants.mediumDelay,
                          child: _buildSuccessMessage(),
                        ),
                        const SizedBox(height: 40),

                        // Info Cards
                        StaggeredListAnimation(
                          itemDelay: const Duration(milliseconds: 150),
                          children: [
                            _buildInfoCard('What happens next?', [
                              '🤖 AI analyzes your photo for verification',
                              '✅ Report becomes available as a cleanup challenge',
                              '👥 Community members can accept the challenge',
                              '🏆 You earn points when it\'s completed!',
                            ], AppTheme.primaryGradient),
                            const SizedBox(height: 20),
                            _buildInfoCard('Your Impact', [
                              '🌱 You\'ve taken the first step to clean up trash',
                              '📍 Your location data helps identify problem areas',
                              '🎯 Every report brings us closer to a cleaner world',
                            ], AppTheme.successGradient),
                            const SizedBox(height: 20),
                            _buildReportIdCard(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 800),
                  child: _buildActionButtons(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: AppTheme.successGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.check_rounded, size: 60, color: Colors.white),
          ),
          // Animated ripple effect
          AnimatedBuilder(
            animation: _celebrationController,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(
                        0.5 * (1 - _celebrationController.value),
                      ),
                      width: 3,
                    ),
                  ),
                  transform: Matrix4.identity()
                    ..scale(1.0 + (_celebrationController.value * 0.3)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => AppTheme.successGradient.createShader(bounds),
      child: Text(
        'Report Submitted!',
        style: AppTheme.displayMedium.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Text(
        'Thank you for helping clean up our community! Your report is being analyzed by our AI system.',
        style: AppTheme.bodyLarge.copyWith(
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    List<String> items,
    LinearGradient gradient,
  ) {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  title.contains('next')
                      ? Icons.timeline_rounded
                      : Icons.eco_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return SlideInAnimation(
              delay: Duration(milliseconds: 100 + (index * 50)),
              beginOffset: const Offset(0.2, 0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReportIdCard() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppTheme.infoBlue.withOpacity(0.05),
      border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Reference',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.infoBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Report ID',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.reportId.length > 12
                      ? '${widget.reportId.substring(0, 12)}...'
                      : widget.reportId,
                  style: AppTheme.titleMedium.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: AppTheme.infoBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ModernGradientButton(
          text: 'Report More Trash',
          onPressed: () => _reportMore(context),
          icon: Icons.camera_alt_rounded,
          gradient: AppTheme.primaryGradient,
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        ModernGradientButton(
          text: 'Find Cleanup Challenges',
          onPressed: () => _findChallenges(context),
          icon: Icons.search_rounded,
          isOutlined: true,
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        ModernGradientButton(
          text: 'Back to Home',
          onPressed: () => _goHome(context),
          icon: Icons.home_rounded,
          gradient: LinearGradient(
            colors: [AppTheme.textSecondary, AppTheme.borderMedium],
          ),
          width: double.infinity,
        ),
      ],
    );
  }

  void _reportMore(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _findChallenges(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
