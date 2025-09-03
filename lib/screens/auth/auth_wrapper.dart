// lib/screens/auth/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trash_tagger/screens/home/home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'login_screen.dart';
import '../home/main_ navigation_screen.dart';

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
          return MainNavigationScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
