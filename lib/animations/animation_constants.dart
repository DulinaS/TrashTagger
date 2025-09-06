// lib/animations/animation_constants.dart - Enhanced for Modern UI
import 'package:flutter/material.dart';

class AnimationConstants {
  // Duration constants - Enhanced with more options
  static const Duration extraFastDuration = Duration(milliseconds: 150);
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration slowDuration = Duration(milliseconds: 600);
  static const Duration extraSlowDuration = Duration(milliseconds: 800);
  static const Duration ultraSlowDuration = Duration(milliseconds: 1200);

  // Curve constants - Modern easing curves
  static const Curve defaultCurve = Curves.easeOut;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOut;
  static const Curve sharpCurve = Curves.easeIn;
  static const Curve modernCurve = Curves.easeInOutCubic;
  static const Curve dramaticCurve = Curves.easeInOutBack;
  static const Curve gentleCurve = Curves.easeInOutQuart;

  // Animation delays - Various timing options
  static const Duration microDelay = Duration(milliseconds: 50);
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration mediumDelay = Duration(milliseconds: 300);
  static const Duration longDelay = Duration(milliseconds: 500);
  static const Duration extraLongDelay = Duration(milliseconds: 800);

  // Staggered animation intervals
  static const int staggerDelayMs = 100;
  static const int cardStaggerDelayMs = 50;
  static const int listStaggerDelayMs = 80;
  static const int gridStaggerDelayMs = 120;

  // Hero animation durations
  static const Duration heroTransition = Duration(milliseconds: 600);
  static const Duration pageTransition = Duration(milliseconds: 500);

  // Loading and refresh durations
  static const Duration refreshDuration = Duration(milliseconds: 1500);
  static const Duration loadingDuration = Duration(milliseconds: 2000);

  // Micro-interaction durations
  static const Duration buttonPress = Duration(milliseconds: 150);
  static const Duration rippleEffect = Duration(milliseconds: 300);
  static const Duration hoverEffect = Duration(milliseconds: 200);

  // Offset constants for slide animations
  static const Offset slideFromRight = Offset(1.0, 0.0);
  static const Offset slideFromLeft = Offset(-1.0, 0.0);
  static const Offset slideFromTop = Offset(0.0, -1.0);
  static const Offset slideFromBottom = Offset(0.0, 1.0);
  static const Offset slideFromBottomRight = Offset(1.0, 1.0);
  static const Offset slideFromTopLeft = Offset(-1.0, -1.0);

  // Scale constants
  static const double scaleSmall = 0.8;
  static const double scaleMedium = 0.9;
  static const double scaleNormal = 1.0;
  static const double scaleLarge = 1.1;
  static const double scaleXLarge = 1.2;

  // Rotation constants (in turns)
  static const double quarterTurn = 0.25;
  static const double halfTurn = 0.5;
  static const double fullTurn = 1.0;

  // Opacity constants
  static const double fadeStart = 0.0;
  static const double fadePartial = 0.5;
  static const double fadeEnd = 1.0;

  // Common animation combinations
  static AnimationInfo get fadeInUp => AnimationInfo(
    duration: mediumDuration,
    curve: smoothCurve,
    delay: shortDelay,
    type: AnimationType.fadeSlide,
  );

  static AnimationInfo get scaleInBounce => AnimationInfo(
    duration: slowDuration,
    curve: bounceCurve,
    delay: mediumDelay,
    type: AnimationType.scale,
  );

  static AnimationInfo get slideInLeft => AnimationInfo(
    duration: mediumDuration,
    curve: modernCurve,
    delay: shortDelay,
    type: AnimationType.slide,
  );
}

enum AnimationType { fade, scale, slide, rotate, fadeSlide, scaleSlide, custom }

class AnimationInfo {
  final Duration duration;
  final Curve curve;
  final Duration delay;
  final AnimationType type;
  final Offset? slideOffset;
  final double? scaleValue;

  const AnimationInfo({
    required this.duration,
    required this.curve,
    required this.delay,
    required this.type,
    this.slideOffset,
    this.scaleValue,
  });
}
