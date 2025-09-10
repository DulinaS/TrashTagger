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
        // Show loading screen while auth state is being determined
        if (authProvider.isLoading) {
          return _buildLoadingScreen();
        }

        // If not authenticated, show login screen
        if (!authProvider.isAuthenticated || authProvider.user == null) {
          debugPrint('🔐 AuthWrapper: User not authenticated, showing login');
          return LoginScreen();
        }

        // User is authenticated - load user data and check onboarding status
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).loadCurrentUser(authProvider.user!.uid);
        });

        // Check if THIS USER has completed onboarding (user-specific)
        return FutureBuilder<bool>(
          future: _checkUserOnboardingStatus(authProvider.user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            final hasCompletedOnboarding = snapshot.data ?? false;

            // Debug print to help track the flow
            debugPrint(
              '🔍 AuthWrapper: User ${authProvider.user!.uid} authenticated, onboarding completed: $hasCompletedOnboarding',
            );

            // If onboarding not completed, show welcome screen
            if (!hasCompletedOnboarding) {
              debugPrint(
                '📝 AuthWrapper: Showing onboarding flow for user ${authProvider.user!.uid}',
              );
              return WelcomeScreen();
            }

            // If onboarding completed, go directly to main app
            debugPrint(
              '🏠 AuthWrapper: Showing main app for user ${authProvider.user!.uid}',
            );
            return MainNavigationScreen();
          },
        );
      },
    );
  }

  // ✅ USER-SPECIFIC onboarding check
  Future<bool> _checkUserOnboardingStatus(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use user ID as part of the key
      final key = 'onboarding_completed_$userId';
      final completed = prefs.getBool(key) ?? false;
      debugPrint('🔍 Onboarding status for user $userId: $completed');
      return completed;
    } catch (e) {
      debugPrint('Error checking onboarding status for user $userId: $e');
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
