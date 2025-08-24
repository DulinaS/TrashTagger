// lib/animations/page_transitions.dart
import 'package:flutter/material.dart';
import 'animation_constants.dart';

class PageTransitions {
  /// Slide transition from right to left
  static PageRouteBuilder slideFromRight({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.defaultCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: child,
        );
      },
    );
  }

  /// Slide transition from left to right
  static PageRouteBuilder slideFromLeft({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.defaultCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: child,
        );
      },
    );
  }

  /// Slide transition from bottom to top
  static PageRouteBuilder slideFromBottom({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.defaultCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: child,
        );
      },
    );
  }

  /// Fade transition with optional scale
  static PageRouteBuilder fadeWithScale({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.defaultCurve,
    double beginScale = 0.8,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: beginScale,
              end: 1.0,
            ).animate(CurvedAnimation(parent: animation, curve: curve)),
            child: child,
          ),
        );
      },
    );
  }

  /// Scale transition
  static PageRouteBuilder scale({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.bounceCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: child,
        );
      },
    );
  }

  /// Rotation transition
  static PageRouteBuilder rotation({
    required Widget page,
    Duration duration = AnimationConstants.slowDuration,
    Curve curve = AnimationConstants.defaultCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Custom hero-like transition for specific widgets
  static PageRouteBuilder heroLike({
    required Widget page,
    required String heroTag,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.defaultCurve,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Slide and fade combination
  static PageRouteBuilder slideAndFade({
    required Widget page,
    Duration duration = AnimationConstants.mediumDuration,
    Curve curve = AnimationConstants.defaultCurve,
    Offset beginOffset = const Offset(0.0, 1.0),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: curve)),
            child: child,
          ),
        );
      },
    );
  }
}
