import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../animations/custom_animations.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  final bool showLogo;

  const LoadingWidget({
    Key? key,
    this.message = 'Loading...',
    this.showLogo = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showLogo)
            PulseAnimation(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryEmerald.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryEmerald),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
