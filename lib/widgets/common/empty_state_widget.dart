// lib/widgets/common/empty_state_widget.dart
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;
  final LinearGradient? iconGradient;
  final bool showAnimation;

  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionText,
    this.onAction,
    this.iconGradient,
    this.showAnimation = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon
            if (showAnimation)
              ScaleInAnimation(
                delay: AnimationConstants.shortDelay,
                child: _buildIcon(),
              )
            else
              _buildIcon(),

            const SizedBox(height: 32),

            // Title
            if (showAnimation)
              SlideInAnimation(
                delay: AnimationConstants.mediumDelay,
                beginOffset: const Offset(0, 0.2),
                child: _buildTitle(),
              )
            else
              _buildTitle(),

            const SizedBox(height: 12),

            // Message
            if (showAnimation)
              SlideInAnimation(
                delay: AnimationConstants.longDelay,
                beginOffset: const Offset(0, 0.2),
                child: _buildMessage(),
              )
            else
              _buildMessage(),

            // Action Button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              if (showAnimation)
                ScaleInAnimation(
                  delay: AnimationConstants.extraLongDelay,
                  child: _buildActionButton(),
                )
              else
                _buildActionButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: iconGradient ?? AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (iconGradient?.colors.first ?? AppTheme.primaryEmerald)
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 60, color: Colors.white),
    );
  }

  Widget _buildTitle() {
    return Text(
      title,
      style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMessage() {
    return Text(
      message,
      style: AppTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionButton() {
    return Container(
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
          onTap: onAction,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  actionText!,
                  style: AppTheme.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
