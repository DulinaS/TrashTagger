// lib/screens/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../animations/floating_shape_animation.dart';
import '../../models/onboarding_model.dart';
import 'oboarding_completion_screen.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  PageController _pageController = PageController();
  int _currentPage = 0;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _rotateController;
  late AnimationController _scaleController;

  // Animations
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  final List<OnboardingPage> _pages = OnboardingData.getPages();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startInitialAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: AnimationConstants.extraLongDuration,
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: AnimationConstants.extraSlowDuration,
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  void _startInitialAnimations() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _slideController.forward();
        _fadeController.forward();
        _bounceController.repeat(reverse: true);
        _rotateController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _bounceController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          _buildOnboardingContent(),
          _buildFloatingShapes(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryEmerald.withOpacity(0.1),
            AppTheme.primaryTeal.withOpacity(0.1),
            AppTheme.accentPurple.withOpacity(0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingContent() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        _scaleController.reset();
        _scaleController.forward();
        HapticFeedback.lightImpact();
      },
      children: [
        _buildWelcomePage(),
        ..._pages.map((page) => _buildFeaturePage(page)),
        _buildGetStartedPage(),
      ],
    );
  }

  Widget _buildWelcomePage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Logo
              ScaleTransition(
                scale: _bounceAnimation,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryEmerald.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // Welcome Text
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradient.createShader(bounds),
                          child: Text(
                            'Welcome to',
                            style: AppTheme.headlineLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradient.createShader(bounds),
                          child: Text(
                            'TrashTagger',
                            style: AppTheme.displayLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 48,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Join the movement to make our planet cleaner, one report at a time',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),

              // Page Indicator and Continue Button
              _buildPageControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePage(OnboardingPage page) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Animated Icon
            RotationTransition(
              turns: _rotateAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: page.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient.colors.first.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(page.icon, size: 70, color: Colors.white),
              ),
            ),

            const SizedBox(height: 40),

            // Title and Subtitle
            Text(
              page.title,
              style: AppTheme.displayMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              page.subtitle,
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // Description
            Text(
              page.description,
              style: AppTheme.bodyLarge.copyWith(
                height: 1.6,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Features List
            ...page.features.asMap().entries.map((entry) {
              return SlideInAnimation(
                delay: Duration(milliseconds: 200 * entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        entry.value.split(' ')[0],
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          entry.value.substring(entry.value.indexOf(' ') + 1),
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const Spacer(),

            _buildPageControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildGetStartedPage() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Success Animation
            PulseAnimation(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: AppTheme.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successGreen.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 50),

            // Ready Text
            Text(
              'You\'re All Set!',
              style: AppTheme.displayMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.successGreen,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Text(
              'Start making a difference today',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            Text(
              'Ready to join thousands of eco-warriors making our planet cleaner? Let\'s begin your journey!',
              style: AppTheme.bodyLarge.copyWith(
                height: 1.6,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Get Started Button
            SlideInAnimation(
              beginOffset: const Offset(0, 0.5),
              child: ModernGradientButton(
                text: 'Get Started',
                onPressed: _completeOnboarding,
                gradient: AppTheme.primaryGradient,
                icon: Icons.rocket_launch_rounded,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),

            const SizedBox(height: 20),

            _buildPageIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageControls() {
    return Column(
      children: [
        _buildPageIndicator(),
        const SizedBox(height: 30),
        Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: ModernGradientButton(
                  text: 'Back',
                  onPressed: _previousPage,
                  isOutlined: true,
                  gradient: AppTheme.primaryGradient,
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 20),
            Expanded(
              child: ModernGradientButton(
                text: _currentPage == (_pages.length + 1)
                    ? 'Get Started'
                    : 'Next',
                onPressed: _currentPage == (_pages.length + 1)
                    ? _completeOnboarding
                    : _nextPage,
                gradient: AppTheme.primaryGradient,
                icon: _currentPage == (_pages.length + 1)
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_currentPage < (_pages.length + 1))
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Skip',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            ),
          ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    final totalPages =
        _pages.length + 2; // Welcome + Feature pages + Get Started
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        return AnimatedContainer(
          duration: AnimationConstants.fastDuration,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: _currentPage == index ? AppTheme.primaryGradient : null,
            color: _currentPage == index ? null : AppTheme.borderLight,
          ),
        );
      }),
    );
  }

  Widget _buildFloatingShapes() {
    return Stack(
      children: [
        // Floating circles
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
                    AppTheme.accentCoral.withOpacity(0.3),
                    AppTheme.accentAmber.withOpacity(0.2),
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
                    AppTheme.primaryTeal.withOpacity(0.2),
                    AppTheme.accentPurple.withOpacity(0.3),
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
                    AppTheme.primaryEmerald.withOpacity(0.4),
                    AppTheme.successGreen.withOpacity(0.2),
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

  void _nextPage() {
    final totalPages = _pages.length + 2;
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: AnimationConstants.mediumDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: AnimationConstants.mediumDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    try {
      // ✅ Save onboarding completion status first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      // Navigate to completion screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OnboardingCompletionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: AnimationConstants.extraSlowDuration,
        ),
      );
    } catch (e) {
      debugPrint('Error saving onboarding status: $e');
      // Continue with navigation even if SharedPreferences fails
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OnboardingCompletionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: AnimationConstants.extraSlowDuration,
        ),
      );
    }
  }
}
