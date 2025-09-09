// lib/screens/onboarding/onboarding_completion_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../home/main_ navigation_screen.dart';

class OnboardingCompletionScreen extends StatefulWidget {
  @override
  _OnboardingCompletionScreenState createState() =>
      _OnboardingCompletionScreenState();
}

class _OnboardingCompletionScreenState extends State<OnboardingCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _textController;

  late Animation<double> _checkScale;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCelebration();
  }

  void _initializeAnimations() {
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );

    _textFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
  }

  void _startCelebration() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      _checkController.forward();

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _textController.forward();

      // Auto navigate after celebration
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) _navigateToMain();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.successGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Check
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 80,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Success Text
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      Text(
                        'Welcome Aboard!',
                        style: AppTheme.displayMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'You\'re now part of the\nTrashTagger community!',
                        style: AppTheme.titleLarge.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToMain() async {
    try {
      // ✅ Save onboarding completion status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      // ✅ Navigate to main app instead of welcome screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MainNavigationScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 1000),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error saving onboarding status: $e');
      // Fallback navigation even if SharedPreferences fails
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }
}
