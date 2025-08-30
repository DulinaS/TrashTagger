// lib/screens/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trash_tagger/models/user_model.dart'
    show UserModel, UserSettings;
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _safetyWarningsEnabled = true;
  double _searchRadius = 5.0;
  String _selectedLanguage = 'English';
  bool _challengeNotifications = true;
  bool _achievementNotifications = true;
  bool _leaderboardNotifications = true;
  bool _reminderNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;

    if (user != null) {
      setState(() {
        _notificationsEnabled = user.settings.notificationsEnabled;
        _safetyWarningsEnabled = user.settings.safetyWarningsEnabled;
        _searchRadius = user.settings.radius;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Notifications Section
            _buildNotificationSettings(),
            const SizedBox(height: 24),

            // Safety Settings
            _buildSafetySettings(),
            const SizedBox(height: 24),

            // Location Settings
            _buildLocationSettings(),
            const SizedBox(height: 24),

            // App Settings
            _buildAppSettings(),
            const SizedBox(height: 24),

            // Account Settings
            _buildAccountSettings(),
            const SizedBox(height: 24),

            // About Section
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safety & Privacy', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Safety Warnings'),
              subtitle: const Text('Show warnings for hazardous materials'),
              value: _safetyWarningsEnabled,
              onChanged: (value) {
                setState(() => _safetyWarningsEnabled = value);
                _updateSettings();
              },
              activeColor: AppTheme.primaryGreen,
            ),

            ListTile(
              title: const Text('Location Privacy'),
              subtitle: const Text('Manage how your location is shared'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showLocationPrivacyDialog();
              },
            ),

            ListTile(
              title: const Text('Data & Privacy'),
              subtitle: const Text('Control your data and privacy settings'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showPrivacyInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location Settings', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            Text(
              'Search Radius: ${_searchRadius.toStringAsFixed(1)} km',
              style: AppTheme.labelMedium,
            ),
            const SizedBox(height: 8),

            Slider(
              value: _searchRadius,
              min: 1.0,
              max: 50.0,
              divisions: 49,
              label: '${_searchRadius.toStringAsFixed(1)} km',
              onChanged: (value) {
                setState(() => _searchRadius = value);
              },
              onChangeEnd: (value) {
                _updateSettings();
              },
              activeColor: AppTheme.primaryGreen,
            ),

            Text(
              'Reports and challenges within this radius will be shown',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Settings', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('Language'),
              subtitle: Text(_selectedLanguage),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showLanguageSelector();
              },
            ),

            ListTile(
              title: const Text('Theme'),
              subtitle: const Text('Light Mode'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showThemeSelector();
              },
            ),

            ListTile(
              title: const Text('Clear Cache'),
              subtitle: const Text('Free up storage space'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showClearCacheDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('Edit Profile'),
              subtitle: const Text('Update your name and photo'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to edit profile
              },
            ),

            ListTile(
              title: const Text('Change Password'),
              subtitle: const Text('Update your password'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showChangePasswordDialog();
              },
            ),

            ListTile(
              title: const Text('Export Data'),
              subtitle: const Text('Download your data'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showExportDataDialog();
              },
            ),

            ListTile(
              title: Text(
                'Delete Account',
                style: TextStyle(color: AppTheme.dangerRed),
              ),
              subtitle: const Text('Permanently delete your account'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.dangerRed,
              ),
              onTap: () {
                _showDeleteAccountDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showHelpDialog();
              },
            ),

            ListTile(
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Show terms
              },
            ),

            ListTile(
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Show privacy policy
              },
            ),

            ListTile(
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
              trailing: const Text('Latest'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSettings() {
    // Update user settings in Firestore
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;

    if (user != null) {
      final updatedUser = UserModel(
        id: user.id,
        name: user.name,
        email: user.email,
        photoURL: user.photoURL,
        totalPoints: user.totalPoints,
        badges: user.badges,
        level: user.level,
        joinDate: user.joinDate,
        lastActive: user.lastActive,
        settings: UserSettings(
          notificationsEnabled: _notificationsEnabled,
          radius: _searchRadius,
          safetyWarningsEnabled: _safetyWarningsEnabled,
        ),
        stats: user.stats,
      );

      userProvider.updateUser(updatedUser);
    }
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () {
                setState(() => _selectedLanguage = 'English');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Spanish'),
              onTap: () {
                setState(() => _selectedLanguage = 'Spanish');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: const Text('Dark mode coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Privacy'),
        content: const Text(
          'Your location is only used to show nearby trash reports and challenges. '
          'Coordinates are rounded for privacy and never shared with other users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data & Privacy'),
        content: const Text(
          'TrashTagger collects minimal data necessary for the app to function. '
          'Your personal information is never sold or shared with third parties.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear stored images and temporary data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear cache logic
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text(
          'Password reset email will be sent to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Send password reset email
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Your data will be prepared and emailed to you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data export requested')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: AppTheme.dangerRed),
        ),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Final Confirmation',
          style: TextStyle(color: AppTheme.dangerRed),
        ),
        content: const Text('Type "DELETE" to confirm account deletion.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧 Email: support@trashtagger.com'),
            SizedBox(height: 8),
            Text('🌐 Website: www.trashtagger.com'),
            SizedBox(height: 8),
            Text('📱 Follow us on social media for updates'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications', style: AppTheme.headlineMedium),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Enable all notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                _updateSettings();
              },
              activeColor: AppTheme.primaryGreen,
            ),

            // Challenge Notifications
            SwitchListTile(
              title: const Text('Challenge Notifications'),
              subtitle: const Text(
                'Get notified about new cleanup opportunities',
              ),
              value: _challengeNotifications && _notificationsEnabled,
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() => _challengeNotifications = value);
                      _updateNotificationPreferences();
                    }
                  : null,
              activeColor: AppTheme.primaryGreen,
            ),

            // Achievement Notifications
            SwitchListTile(
              title: const Text('Achievement Notifications'),
              subtitle: const Text('Get notified about badges and level ups'),
              value: _achievementNotifications && _notificationsEnabled,
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() => _achievementNotifications = value);
                      _updateNotificationPreferences();
                    }
                  : null,
              activeColor: AppTheme.primaryGreen,
            ),

            // Leaderboard Notifications
            SwitchListTile(
              title: const Text('Leaderboard Updates'),
              subtitle: const Text('Get notified about ranking changes'),
              value: _leaderboardNotifications && _notificationsEnabled,
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() => _leaderboardNotifications = value);
                      _updateNotificationPreferences();
                    }
                  : null,
              activeColor: AppTheme.primaryGreen,
            ),

            // Reminder Notifications
            SwitchListTile(
              title: const Text('Reminder Notifications'),
              subtitle: const Text('Get reminded about pending challenges'),
              value: _reminderNotifications && _notificationsEnabled,
              onChanged: _notificationsEnabled
                  ? (value) {
                      setState(() => _reminderNotifications = value);
                      _updateNotificationPreferences();
                    }
                  : null,
              activeColor: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  void _updateNotificationPreferences() {
    NotificationService.updateNotificationPreferences(
      challengeNotifications: _challengeNotifications,
      achievementNotifications: _achievementNotifications,
      leaderboardNotifications: _leaderboardNotifications,
    );
  }
}
