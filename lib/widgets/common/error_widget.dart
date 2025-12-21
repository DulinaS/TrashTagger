// lib/widgets/common/error_widget.dart - Updated with modern design
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryText;
  final IconData? icon;
  final String? title;
  final bool showRetryButton;

  const ErrorDisplayWidget({
    Key? key,
    required this.message,
    this.onRetry,
    this.retryText,
    this.icon,
    this.title,
    this.showRetryButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ModernCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon with Animation
              ScaleInAnimation(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.errorGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.errorRed.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon ?? Icons.error_outline_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error Title
              SlideInAnimation(
                beginOffset: const Offset(0, 0.2),
                delay: AnimationConstants.shortDelay,
                child: Text(
                  title ?? 'Oops! Something went wrong',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.errorRed,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // Error Message
              SlideInAnimation(
                beginOffset: const Offset(0, 0.2),
                delay: AnimationConstants.mediumDelay,
                child: Text(
                  message,
                  style: AppTheme.bodyMedium.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),

              // Retry Button
              if (showRetryButton && onRetry != null) ...[
                const SizedBox(height: 32),
                ScaleInAnimation(
                  delay: AnimationConstants.longDelay,
                  child: ModernGradientButton(
                    text: retryText ?? 'Try Again',
                    onPressed: onRetry,
                    icon: Icons.refresh_rounded,
                    gradient: AppTheme.primaryGradient,
                  ),
                ),
              ],

              // Help Text
              if (showRetryButton) ...[
                const SizedBox(height: 16),
                SlideInAnimation(
                  beginOffset: const Offset(0, 0.2),
                  delay: AnimationConstants.extraLongDelay,
                  child: Text(
                    'If the problem persists, please contact support',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact error widget for smaller spaces
class CompactErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryText;

  const CompactErrorWidget({
    Key? key,
    required this.message,
    this.onRetry,
    this.retryText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppTheme.errorRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ModernGradientButton(
                text: retryText ?? 'Retry',
                onPressed: onRetry,
                gradient: AppTheme.errorGradient,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Network error widget with specific messaging
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({Key? key, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorDisplayWidget(
      icon: Icons.wifi_off_rounded,
      title: 'Connection Problem',
      message: 'Please check your internet connection and try again.',
      onRetry: onRetry,
      retryText: 'Retry Connection',
    );
  }
}

/// Server error widget
class ServerErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorWidget({Key? key, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorDisplayWidget(
      icon: Icons.cloud_off_rounded,
      title: 'Server Error',
      message:
          'Our servers are currently experiencing issues. Please try again later.',
      onRetry: onRetry,
      retryText: 'Try Again',
    );
  }
}

/// Permission error widget
class PermissionErrorWidget extends StatelessWidget {
  final String permission;
  final VoidCallback? onRetry;

  const PermissionErrorWidget({
    Key? key,
    required this.permission,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorDisplayWidget(
      icon: Icons.lock_outline_rounded,
      title: 'Permission Required',
      message:
          'TrashTagger needs $permission permission to work properly. Please grant permission in your device settings.',
      onRetry: onRetry,
      retryText: 'Open Settings',
    );
  }
}

/// Generic error boundary widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(String error)? errorBuilder;

  const ErrorBoundary({Key? key, required this.child, this.errorBuilder})
    : super(key: key);

  @override
  _ErrorBoundaryState createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  String? _error;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception.toString();
      });
    };
  }

  void _clearError() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!) ??
          ErrorDisplayWidget(
            message: _error!,
            onRetry: _clearError,
            retryText: 'Dismiss',
          );
    }

    return widget.child;
  }
}
