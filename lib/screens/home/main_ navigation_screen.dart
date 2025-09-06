// lib/screens/navigation/main_navigation_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../map/map_screen.dart';
import '../challenges/challenges_screen.dart';
import '../profile/profile_screen.dart';
import '../../themes/app_theme.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../report/camera_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late List<AnimationController> _iconControllers;
  late List<Animation<double>> _iconAnimations;

  final List<Widget> _screens = [
    HomeScreen(),
    MapScreen(),
    CameraScreen(),
    ChallengesScreen(),
    ProfileScreen(),
  ];

  final List<BottomNavItem> _navItems = [
    BottomNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      gradient: AppTheme.primaryGradient,
    ),
    BottomNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Map',
      gradient: LinearGradient(
        colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
      ),
    ),
    BottomNavItem(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt_rounded,
      label: 'Report',
      gradient: LinearGradient(
        colors: [AppTheme.accentCoral, AppTheme.accentAmber],
      ),
      isCenter: true,
    ),
    BottomNavItem(
      icon: Icons.cleaning_services_outlined,
      activeIcon: Icons.cleaning_services_rounded,
      label: 'Challenges',
      gradient: LinearGradient(
        colors: [AppTheme.accentPurple, AppTheme.primaryTeal],
      ),
    ),
    BottomNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      gradient: LinearGradient(
        colors: [AppTheme.warningAmber, AppTheme.accentAmber],
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    // Initialize animation controllers for each tab
    _iconControllers = List.generate(
      _navItems.length,
      (index) => AnimationController(
        duration: AnimationConstants.fastDuration,
        vsync: this,
      ),
    );

    _iconAnimations = _iconControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: AnimationConstants.bounceCurve,
        ),
      );
    }).toList();

    // Animate the initial selected tab
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) _iconControllers[_currentIndex].forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _iconControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    // Animate icon transitions
    for (int i = 0; i < _iconControllers.length; i++) {
      if (i == index) {
        _iconControllers[i].forward();
      } else {
        _iconControllers[i].reverse();
      }
    }

    _pageController.animateToPage(
      index,
      duration: AnimationConstants.mediumDuration,
      curve: AnimationConstants.modernCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // Update icon animations when swiping
          for (int i = 0; i < _iconControllers.length; i++) {
            if (i == index) {
              _iconControllers[i].forward();
            } else {
              _iconControllers[i].reverse();
            }
          }
        },
        children: _screens,
      ),
      bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  Widget _buildModernBottomNavBar() {
    return SlideInAnimation(
      beginOffset: AnimationConstants.slideFromBottom,
      delay: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowHeavy,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _currentIndex == index;

            return _buildNavItem(item, index, isSelected);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem(BottomNavItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedBuilder(
        animation: _iconAnimations[index],
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: item.isCenter
                ? _buildCenterNavItem(item, isSelected)
                : _buildRegularNavItem(item, index, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCenterNavItem(BottomNavItem item, bool isSelected) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: item.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: item.gradient.colors.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: AnimatedBuilder(
        animation: _iconAnimations[2], // Camera is at index 2
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_iconAnimations[2].value * 0.1),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              color: Colors.white,
              size: 28,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegularNavItem(BottomNavItem item, int index, bool isSelected) {
    return AnimatedContainer(
      duration: AnimationConstants.fastDuration,
      curve: AnimationConstants.smoothCurve,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected ? item.gradient.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _iconAnimations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_iconAnimations[index].value * 0.2),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: isSelected
                      ? BoxDecoration(
                          gradient: item.gradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: item.gradient.colors.first.withOpacity(
                                0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? Colors.white : AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: AnimationConstants.fastDuration,
            style: AppTheme.labelSmall.copyWith(
              color: isSelected
                  ? item.gradient.colors.first
                  : AppTheme.textTertiary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final LinearGradient gradient;
  final bool isCenter;

  BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.gradient,
    this.isCenter = false,
  });
}

// Extension to add opacity to gradients
extension GradientExtension on LinearGradient {
  LinearGradient withOpacity(double opacity) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors.map((color) => color.withOpacity(opacity)).toList(),
      stops: stops,
      transform: transform,
    );
  }
}

// Global key for accessing navigation state
class MainNavigationController {
  static final GlobalKey<_MainNavigationScreenState> _key =
      GlobalKey<_MainNavigationScreenState>();

  static GlobalKey<_MainNavigationScreenState> get key => _key;

  static void onTabTapped(int index) {
    _key.currentState?._onTabTapped(index);
  }
}
