// lib/animations/custom_animations.dart - Fixed for Modern UI (No ParentData Issues)
import 'package:flutter/material.dart';
import 'animation_constants.dart';

/// Enhanced slide-in animation with multiple directions and effects
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset beginOffset;
  final bool autoStart;
  final bool enableFade;
  final double? fadeFrom;

  const SlideInAnimation({
    Key? key,
    required this.child,
    this.duration = AnimationConstants.mediumDuration,
    this.delay = Duration.zero,
    this.curve = AnimationConstants.modernCurve,
    this.beginOffset = const Offset(0, 0.3),
    this.autoStart = true,
    this.enableFade = true,
    this.fadeFrom,
  }) : super(key: key);

  @override
  _SlideInAnimationState createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (widget.enableFade) {
      _fadeAnimation = Tween<double>(
        begin: widget.fadeFrom ?? 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    } else {
      _fadeAnimation = AlwaysStoppedAnimation(1.0);
    }

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startAnimation() => _controller.forward();
  void reverseAnimation() => _controller.reverse();
  void resetAnimation() => _controller.reset();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Enhanced staggered animation with better controls - FIXED
class StaggeredListAnimation extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final Curve curve;
  final Offset beginOffset;
  final bool autoStart;
  final Axis direction;
  final bool reverse;
  final double staggerFactor;

  const StaggeredListAnimation({
    Key? key,
    required this.children,
    this.itemDelay = const Duration(
      milliseconds: AnimationConstants.staggerDelayMs,
    ),
    this.itemDuration = AnimationConstants.mediumDuration,
    this.curve = AnimationConstants.modernCurve,
    this.beginOffset = const Offset(0, 0.3),
    this.autoStart = true,
    this.direction = Axis.vertical,
    this.reverse = false,
    this.staggerFactor = 1.0,
  }) : super(key: key);

  @override
  _StaggeredListAnimationState createState() => _StaggeredListAnimationState();
}

class _StaggeredListAnimationState extends State<StaggeredListAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      widget.children.length,
      (index) =>
          AnimationController(duration: widget.itemDuration, vsync: this),
    );

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: widget.beginOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: widget.curve));
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: widget.curve));
    }).toList();

    if (widget.autoStart) {
      _startStaggeredAnimation();
    }
  }

  void _startStaggeredAnimation() {
    final itemOrder = widget.reverse
        ? List.generate(
            widget.children.length,
            (i) => widget.children.length - 1 - i,
          )
        : List.generate(widget.children.length, (i) => i);

    for (int i = 0; i < itemOrder.length; i++) {
      final delay = Duration(
        milliseconds:
            (widget.itemDelay.inMilliseconds * i * widget.staggerFactor)
                .round(),
      );

      Future.delayed(delay, () {
        if (mounted) _controllers[itemOrder[i]].forward();
      });
    }
  }

  void startAnimation() => _startStaggeredAnimation();
  void reverseAnimation() {
    for (var controller in _controllers.reversed) {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Use proper layout widgets instead of problematic combinations
    if (widget.direction == Axis.horizontal) {
      return Row(
        children: widget.children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, _) {
              return FadeTransition(
                opacity: _fadeAnimations[index],
                child: SlideTransition(
                  position: _slideAnimations[index],
                  child: child,
                ),
              );
            },
          );
        }).toList(),
      );
    } else {
      return Column(
        children: widget.children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, _) {
              return FadeTransition(
                opacity: _fadeAnimations[index],
                child: SlideTransition(
                  position: _slideAnimations[index],
                  child: child,
                ),
              );
            },
          );
        }).toList(),
      );
    }
  }
}

/// Enhanced scale animation with multiple effects
class ScaleInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double beginScale;
  final double endScale;
  final bool autoStart;
  final bool enableFade;
  final bool enableRotation;
  final double rotationTurns;

  const ScaleInAnimation({
    Key? key,
    required this.child,
    this.duration = AnimationConstants.mediumDuration,
    this.delay = Duration.zero,
    this.curve = AnimationConstants.bounceCurve,
    this.beginScale = 0.0,
    this.endScale = 1.0,
    this.autoStart = true,
    this.enableFade = true,
    this.enableRotation = false,
    this.rotationTurns = 0.25,
  }) : super(key: key);

  @override
  _ScaleInAnimationState createState() => _ScaleInAnimationState();
}

class _ScaleInAnimationState extends State<ScaleInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: widget.endScale,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _fadeAnimation = widget.enableFade
        ? Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: _controller, curve: widget.curve))
        : AlwaysStoppedAnimation(1.0);

    _rotationAnimation = widget.enableRotation
        ? Tween<double>(
            begin: 0.0,
            end: widget.rotationTurns,
          ).animate(CurvedAnimation(parent: _controller, curve: widget.curve))
        : AlwaysStoppedAnimation(0.0);

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: RotationTransition(
            turns: _rotationAnimation,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Floating Action Button with enhanced animations
class AnimatedFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String? heroTag;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Duration delay;
  final Duration duration;
  final bool enablePulse;
  final bool enableRotation;

  const AnimatedFAB({
    Key? key,
    required this.onPressed,
    required this.child,
    this.heroTag,
    this.backgroundColor,
    this.foregroundColor,
    this.delay = AnimationConstants.longDelay,
    this.duration = AnimationConstants.mediumDuration,
    this.enablePulse = false,
    this.enableRotation = false,
  }) : super(key: key);

  @override
  _AnimatedFABState createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: AnimationConstants.bounceCurve,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _scaleController.forward();
        if (widget.enablePulse) {
          _pulseController.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale:
              _scaleAnimation.value *
              (widget.enablePulse ? _pulseAnimation.value : 1.0),
          child: FloatingActionButton.extended(
            onPressed: widget.onPressed,
            heroTag: widget.heroTag,
            backgroundColor: widget.backgroundColor,
            foregroundColor: widget.foregroundColor,
            elevation: 8,
            label: widget.child,
          ),
        );
      },
    );
  }
}

/// Enhanced pulse animation with customizable effects
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool repeat;
  final Curve curve;
  final bool enableOpacity;
  final double minOpacity;
  final double maxOpacity;

  const PulseAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(seconds: 2),
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.repeat = true,
    this.curve = Curves.easeInOut,
    this.enableOpacity = false,
    this.minOpacity = 0.7,
    this.maxOpacity = 1.0,
  }) : super(key: key);

  @override
  _PulseAnimationState createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _opacityAnimation = widget.enableOpacity
        ? Tween<double>(
            begin: widget.minOpacity,
            end: widget.maxOpacity,
          ).animate(CurvedAnimation(parent: _controller, curve: widget.curve))
        : AlwaysStoppedAnimation(1.0);

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Shimmer loading animation
class ShimmerAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;
  final bool enabled;

  const ShimmerAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.enabled = true,
  }) : super(key: key);

  @override
  _ShimmerAnimationState createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends State<ShimmerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Typewriter text animation
class TypewriterAnimation extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final bool autoStart;

  const TypewriterAnimation({
    Key? key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 2000),
    this.delay = Duration.zero,
    this.autoStart = true,
  }) : super(key: key);

  @override
  _TypewriterAnimationState createState() => _TypewriterAnimationState();
}

class _TypewriterAnimationState extends State<TypewriterAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.text.substring(0, _animation.value),
          style: widget.style,
        );
      },
    );
  }
}
