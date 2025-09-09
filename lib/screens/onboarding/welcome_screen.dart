// lib/screens/onboarding/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/floating_shape_animation.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _buttonScale;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _textFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _buttonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.bounceOut),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.linear),
    );
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      _logoController.forward();
      _particleController.repeat();

      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _textController.forward();

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _buttonController.forward();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryEmerald.withOpacity(0.8),
              AppTheme.primaryTeal.withOpacity(0.9),
              AppTheme.accentPurple.withOpacity(0.7),
            ],
          ),
        ),
        child: Stack(
          children: [
            //_buildParticleBackground(),
            _buildFloatingShapes(),
            _buildWelcomeContent(),
          ],
        ),
      ),
    );
  }

  /*  Widget _buildParticleBackground() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticleBackgroundPainter(_particleAnimation.value),
          size: Size.infinite,
        );
      },
    );
  } */

  Widget _buildFloatingShapes() {
    return Stack(
      children: [
        Positioned(
          top: 100,
          right: 50,
          child: FloatingShapeAnimation(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          left: 30,
          child: FloatingShapeAnimation(
            delay: const Duration(milliseconds: 1000),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Positioned(
          top: 300,
          left: 20,
          child: FloatingShapeAnimation(
            delay: const Duration(milliseconds: 2000),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Animated Logo
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Transform.rotate(
                    angle: _logoRotation.value * 0.5,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.white.withOpacity(0.9)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        size: 90,
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 60),

            // Animated Text
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    Text(
                      'TrashTagger',
                      style: AppTheme.displayLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 52,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Making the world cleaner,\none report at a time',
                      style: AppTheme.titleLarge.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Animated Button
            ScaleTransition(
              scale: _buttonScale,
              child: Column(
                children: [
                  ModernGradientButton(
                    text: 'Start Your Journey',
                    onPressed: _navigateToOnboarding,
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.9)],
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    borderRadius: 25,
                    icon: Icons.arrow_forward_rounded,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Join thousands of eco-warriors',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _navigateToOnboarding() {
    HapticFeedback.lightImpact();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: AnimationConstants.extraSlowDuration,
      ),
    );
  }
}

// Custom painter for particle background
/* class ParticleBackgroundPainter extends CustomPainter {
  final double animationValue;
  
  ParticleBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw floating particles
    for (int i = 0; i < 50; i++) {
      final x = (size.width * (i % 10) / 10) + 
                (50 * (animationValue + i * 0.1).sin());
      final y = (size.height * (i / 50)) + 
                (30 * (animationValue * 2 + i * 0.05).cos());
      
      final radius = 2 + (3 * (animationValue + i * 0.2).sin()).abs();
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} */
