// lib/animations/floating_shape_animation.dart
import 'package:flutter/material.dart';

class FloatingShapeAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FloatingShapeAnimation({
    Key? key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  _FloatingShapeAnimationState createState() => _FloatingShapeAnimationState();
}

class _FloatingShapeAnimationState extends State<FloatingShapeAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -20),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
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
        return Transform.translate(
          offset: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}
