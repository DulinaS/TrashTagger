// lib/animations/animation_constants.dart
import 'package:flutter/material.dart';

class AnimationConstants {
  // Duration constants
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration slowDuration = Duration(milliseconds: 600);
  static const Duration extraSlowDuration = Duration(milliseconds: 800);

  // Curve constants
  static const Curve defaultCurve = Curves.easeOut;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOut;
  static const Curve sharpCurve = Curves.easeIn;

  // Animation delays
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration mediumDelay = Duration(milliseconds: 300);
  static const Duration longDelay = Duration(milliseconds: 500);

  // Staggered animation intervals
  static const int staggerDelayMs = 100;
  static const int cardStaggerDelayMs = 50;
}
