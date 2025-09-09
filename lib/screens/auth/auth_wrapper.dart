// lib/screens/auth/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../home/main_ navigation_screen.dart';
import 'login_screen.dart';
import '../onboarding/welcome_screen.dart';

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          // Load user data when authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(
              context,
              listen: false,
            ).loadCurrentUser(authProvider.user!.uid);
          });

          // Check if user needs onboarding
          return FutureBuilder<bool>(
            future: _checkOnboardingStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              final hasCompletedOnboarding = snapshot.data ?? false;

              // ✅ If onboarding not completed, show welcome screen
              if (!hasCompletedOnboarding) {
                return WelcomeScreen();
              }

              // ✅ If onboarding completed, go directly to main app
              return MainNavigationScreen();
            },
          );
        } else {
          return LoginScreen();
        }
      },
    );
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') ?? false;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false; // Default to showing onboarding if error occurs
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00C896), Color(0xFF00A085)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
