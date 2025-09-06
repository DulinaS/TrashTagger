// lib/animations/page_transitions.dart - Enhanced for Modern UI
import 'package:flutter/material.dart';
import 'animation_constants.dart';

class PageTransitions {
  /// Modern slide transition from right to left with fade
  static PageRouteBuilder slideFromRight({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.modernCurve,
    bool enableFade = true,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: AnimationConstants.slideFromRight,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final fadeAnimation = enableFade
            ? Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(parent: animation, curve: curve))
            : AlwaysStoppedAnimation(1.0);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }

  /// Enhanced slide with scale transition
  static PageRouteBuilder slideWithScale({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.dramaticCurve,
    Offset beginOffset = AnimationConstants.slideFromBottom,
    double beginScale = 0.8,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        final slideAnimation = Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final scaleAnimation = Tween<double>(
          begin: beginScale,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );
  }

  /// Modern fade with scale and rotation
  static PageRouteBuilder modernFadeScale({
    required Widget page,
    Duration duration = AnimationConstants.slowDuration,
    Curve curve = AnimationConstants.bounceCurve,
    double beginScale = 0.3,
    double rotationTurns = 0.1,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final scaleAnimation = Tween<double>(
          begin: beginScale,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final rotationAnimation = Tween<double>(
          begin: rotationTurns,
          end: 0.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return FadeTransition(
          opacity: fadeAnimation,
          child: RotationTransition(
            turns: rotationAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          ),
        );
      },
    );
  }

  /// Slide and fade combination with secondary animation
  static PageRouteBuilder slideAndFade({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.modernCurve,
    Offset beginOffset = AnimationConstants.slideFromBottom,
    bool enableSecondaryAnimation = true,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final primarySlide = Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final primaryFade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        Widget result = FadeTransition(
          opacity: primaryFade,
          child: SlideTransition(position: primarySlide, child: child),
        );

        // Add secondary animation for the previous page
        if (enableSecondaryAnimation &&
            secondaryAnimation.status != AnimationStatus.dismissed) {
          final secondarySlide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.3, 0.0),
          ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve));

          final secondaryScale = Tween<double>(
            begin: 1.0,
            end: 0.9,
          ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve));

          return Stack(
            children: [
              SlideTransition(
                position: secondarySlide,
                child: ScaleTransition(
                  scale: secondaryScale,
                  child: Container(), // Previous page placeholder
                ),
              ),
              result,
            ],
          );
        }

        return result;
      },
    );
  }

  /// Morphing transition with shared elements
  static PageRouteBuilder morphingTransition({
    required Widget page,
    Duration duration = AnimationConstants.slowDuration,
    Curve curve = AnimationConstants.gentleCurve,
    Color? backgroundColor,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        final fadeAnimation = tween.animate(curvedAnimation);
        final scaleAnimation = Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(curvedAnimation);
        final rotationAnimation = Tween<double>(
          begin: 0.05,
          end: 0.0,
        ).animate(curvedAnimation);

        return Container(
          color: backgroundColor,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: RotationTransition(
              turns: rotationAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          ),
        );
      },
    );
  }

  /// Card-style transition for modal presentations
  static PageRouteBuilder cardStyleTransition({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.modernCurve,
    bool isDismissible = true,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      opaque: false,
      barrierDismissible: isDismissible,
      barrierColor: Colors.black54,
      transitionsBuilder: (context, animation, _, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }

  /// 3D flip transition
  static PageRouteBuilder flipTransition({
    required Widget page,
    Duration duration = AnimationConstants.slowDuration,
    Curve curve = AnimationConstants.modernCurve,
    Axis flipAxis = Axis.horizontal,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        final flipAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return AnimatedBuilder(
          animation: flipAnimation,
          builder: (context, child) {
            final isShowingFrontSide = flipAnimation.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(flipAnimation.value * 3.14159),
              child: isShowingFrontSide
                  ? Container() // Previous page
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: page,
                    ),
            );
          },
        );
      },
    );
  }

  /// Ripple transition effect
  static PageRouteBuilder rippleTransition({
    required Widget page,
    required Offset startPosition,
    Duration duration = AnimationConstants.slowDuration,
    Curve curve = AnimationConstants.modernCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return ClipPath(
              clipper: RippleClipper(animation.value, startPosition),
              child: page,
            );
          },
        );
      },
    );
  }

  /// Zoom transition with fade
  static PageRouteBuilder zoomTransition({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.bounceCurve,
    double beginScale = 0.0,
    double endScale = 1.0,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        final scaleAnimation = Tween<double>(
          begin: beginScale,
          end: endScale,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );
  }

  /// Custom transition builder
  static PageRouteBuilder customTransition({
    required Widget page,
    required Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    )
    transitionBuilder,
    Duration duration = AnimationConstants.mediumDuration,
    bool opaque = true,
    Color? barrierColor,
    bool barrierDismissible = false,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      opaque: opaque,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      transitionsBuilder: transitionBuilder,
    );
  }
}

/// Custom clipper for ripple effect
class RippleClipper extends CustomClipper<Path> {
  final double animationValue;
  final Offset center;

  RippleClipper(this.animationValue, this.center);

  @override
  Path getClip(Size size) {
    final path = Path();
    final maxRadius =
        (size.width > size.height ? size.width : size.height) * 1.5;
    final radius = maxRadius * animationValue;

    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
