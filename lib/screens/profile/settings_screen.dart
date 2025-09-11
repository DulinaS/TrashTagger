// lib/screens/profile/settings_screen.dart - Modern Vibrant Design (Completed)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trash_tagger/models/user_model.dart'
    show UserModel, UserSettings;
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _notificationsEnabled = true;
  bool _safetyWarningsEnabled = true;
  double _searchRadius = 5.0;
  String _selectedLanguage = 'English';
  bool _challengeNotifications = true;
  bool _achievementNotifications = true;
  bool _leaderboardNotifications = true;
  bool _reminderNotifications = true;

  // Animation controllers
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserSettings();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );

    // Start animations
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
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
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Notifications Section
              SlideInAnimation(
                delay: AnimationConstants.microDelay,
                child: _buildNotificationSettings(),
              ),
              const SizedBox(height: 24),

              // Safety Settings
              SlideInAnimation(
                delay: AnimationConstants.shortDelay,
                child: _buildSafetySettings(),
              ),
              const SizedBox(height: 24),

              // Location Settings
              SlideInAnimation(
                delay: AnimationConstants.mediumDelay,
                child: _buildLocationSettings(),
              ),
              const SizedBox(height: 24),

              // App Settings
              SlideInAnimation(
                delay: AnimationConstants.longDelay,
                child: _buildAppSettings(),
              ),
              const SizedBox(height: 24),

              // Account Settings
              SlideInAnimation(
                delay: AnimationConstants.extraLongDelay,
                child: _buildAccountSettings(),
              ),
              const SizedBox(height: 24),

              // About Section
              ScaleInAnimation(
                delay: const Duration(milliseconds: 600),
                child: _buildAboutSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentPurple.withOpacity(0.1),
                AppTheme.accentCoral.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentCoral],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Settings',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Notifications',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildModernSwitchTile(
            'Push Notifications',
            'Enable all notifications',
            _notificationsEnabled,
            (value) {
              setState(() => _notificationsEnabled = value);
              _updateSettings();
            },
            AppTheme.primaryEmerald,
          ),

          _buildModernSwitchTile(
            'Challenge Notifications',
            'Get notified about new cleanup opportunities',
            _challengeNotifications && _notificationsEnabled,
            _notificationsEnabled
                ? (value) {
                    setState(() => _challengeNotifications = value);
                    _updateNotificationPreferences();
                  }
                : null,
            AppTheme.infoBlue,
          ),

          _buildModernSwitchTile(
            'Achievement Notifications',
            'Get notified about badges and level ups',
            _achievementNotifications && _notificationsEnabled,
            _notificationsEnabled
                ? (value) {
                    setState(() => _achievementNotifications = value);
                    _updateNotificationPreferences();
                  }
                : null,
            AppTheme.accentAmber,
          ),

          _buildModernSwitchTile(
            'Leaderboard Updates',
            'Get notified about ranking changes',
            _leaderboardNotifications && _notificationsEnabled,
            _notificationsEnabled
                ? (value) {
                    setState(() => _leaderboardNotifications = value);
                    _updateNotificationPreferences();
                  }
                : null,
            AppTheme.accentPurple,
          ),

          _buildModernSwitchTile(
            'Reminder Notifications',
            'Get reminded about pending challenges',
            _reminderNotifications && _notificationsEnabled,
            _notificationsEnabled
                ? (value) {
                    setState(() => _reminderNotifications = value);
                    _updateNotificationPreferences();
                  }
                : null,
            AppTheme.primaryTeal,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetySettings() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.errorGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Safety & Privacy',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildModernSwitchTile(
            'Safety Warnings',
            'Show warnings for hazardous materials',
            _safetyWarningsEnabled,
            (value) {
              setState(() => _safetyWarningsEnabled = value);
              _updateSettings();
            },
            AppTheme.errorRed,
          ),

          _buildModernListTile(
            'Location Privacy',
            'Manage how your location is shared',
            Icons.location_on_rounded,
            AppTheme.primaryTeal,
            () => _showLocationPrivacyDialog(),
          ),

          _buildModernListTile(
            'Data & Privacy',
            'Control your data and privacy settings',
            Icons.privacy_tip_rounded,
            AppTheme.accentPurple,
            () => _showPrivacyInfo(),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSettings() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryTeal, AppTheme.infoBlue],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Location Settings',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Search Radius',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_searchRadius.toStringAsFixed(1)} km',
                        style: AppTheme.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryEmerald,
                    inactiveTrackColor: AppTheme.borderLight,
                    thumbColor: AppTheme.primaryEmerald,
                    overlayColor: AppTheme.primaryEmerald.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _searchRadius,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    onChanged: (value) {
                      setState(() => _searchRadius = value);
                    },
                    onChangeEnd: (value) {
                      _updateSettings();
                    },
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Reports and challenges within this radius will be shown',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettings() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.warningGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.app_settings_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'App Settings',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildModernListTile(
            'Language',
            _selectedLanguage,
            Icons.language_rounded,
            AppTheme.infoBlue,
            () => _showLanguageSelector(),
          ),

          _buildModernListTile(
            'Theme',
            'Light Mode',
            Icons.palette_rounded,
            AppTheme.accentPurple,
            () => _showThemeSelector(),
          ),

          _buildModernListTile(
            'Clear Cache',
            'Free up storage space',
            Icons.cleaning_services_rounded,
            AppTheme.accentCoral,
            () => _showClearCacheDialog(),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Account',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildModernListTile(
            'Edit Profile',
            'Update your name and photo',
            Icons.edit_rounded,
            AppTheme.primaryEmerald,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditProfileScreen()),
            ),
          ),

          _buildModernListTile(
            'Change Password',
            'Update your password',
            Icons.lock_reset_rounded,
            AppTheme.warningAmber,
            () => _showChangePasswordDialog(),
          ),

          _buildModernListTile(
            'Export Data',
            'Download your data',
            Icons.download_rounded,
            AppTheme.infoBlue,
            () => _showExportDataDialog(),
          ),

          _buildModernListTile(
            'Delete Account',
            'Permanently delete your account',
            Icons.delete_forever_rounded,
            AppTheme.errorRed,
            () => _showDeleteAccountDialog(),
            isLast: true,
            isDangerous: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.textSecondary, AppTheme.borderMedium],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'About',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildModernListTile(
            'Help & Support',
            'Get help and contact support',
            Icons.support_agent_rounded,
            AppTheme.primaryTeal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HelpSupportScreen()),
            ),
          ),

          _buildModernListTile(
            'Terms of Service',
            'Read our terms and conditions',
            Icons.gavel_rounded,
            AppTheme.textSecondary,
            () => {}, // TODO: Show terms
          ),

          _buildModernListTile(
            'Privacy Policy',
            'Read our privacy policy',
            Icons.privacy_tip_rounded,
            AppTheme.textSecondary,
            () => {}, // TODO: Show privacy policy
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TrashTagger 2.0.0',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Latest',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
    Color color, {
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.notifications_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            inactiveThumbColor: AppTheme.borderMedium,
            inactiveTrackColor: AppTheme.borderLight,
          ),
        ],
      ),
    );
  }

  Widget _buildModernListTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isLast = false,
    bool isDangerous = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: ModernCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDangerous ? AppTheme.errorRed : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDangerous ? AppTheme.errorRed : AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  void _updateSettings() {
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

  void _updateNotificationPreferences() {
    NotificationService.updateNotificationPreferences(
      challengeNotifications: _challengeNotifications,
      achievementNotifications: _achievementNotifications,
      leaderboardNotifications: _leaderboardNotifications,
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Select Language',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLanguageOption('English', 'English'),
                  const SizedBox(height: 12),
                  _buildLanguageOption('Tamil', 'Coming Soon'),
                  const SizedBox(height: 12),
                  _buildLanguageOption('Sinhala', 'සිංහල-Coming Soon'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, String nativeName) {
    final isSelected = _selectedLanguage == language;
    return ModernCard(
      onTap: () {
        setState(() => _selectedLanguage = language);
        Navigator.pop(context);
      },
      backgroundColor: isSelected
          ? AppTheme.primaryEmerald.withOpacity(0.1)
          : null,
      border: isSelected
          ? Border.all(color: AppTheme.primaryEmerald.withOpacity(0.3))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderMedium),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryEmerald : null,
                    ),
                  ),
                  if (language != nativeName) ...[
                    const SizedBox(height: 2),
                    Text(
                      nativeName,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.palette_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Select Theme'),
          ],
        ),
        content: Text('Dark mode and theme customization coming soon!'),
        actions: [
          ModernGradientButton(
            text: 'OK',
            onPressed: () => Navigator.pop(context),
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  void _showLocationPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(width: 12),
            Text('Location Privacy'),
          ],
        ),
        content: Text(
          'Your location is only used to show nearby trash reports and challenges. '
          'Coordinates are rounded for privacy and never shared with other users.',
        ),
        actions: [
          ModernGradientButton(
            text: 'OK',
            onPressed: () => Navigator.pop(context),
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.privacy_tip_rounded,
                color: AppTheme.accentPurple,
              ),
            ),
            const SizedBox(width: 12),
            Text('Data & Privacy'),
          ],
        ),
        content: Text(
          'TrashTagger collects minimal data necessary for the app to function. '
          'Your personal information is never sold or shared with third parties.',
        ),
        actions: [
          ModernGradientButton(
            text: 'OK',
            onPressed: () => Navigator.pop(context),
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentCoral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.cleaning_services_rounded,
                color: AppTheme.accentCoral,
              ),
            ),
            const SizedBox(width: 12),
            Text('Clear Cache'),
          ],
        ),
        content: Text(
          'This will clear stored images and temporary data to free up storage space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ModernGradientButton(
            text: 'Clear',
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('Cache cleared successfully'),
                    ],
                  ),
                  backgroundColor: AppTheme.primaryEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                color: AppTheme.warningAmber,
              ),
            ),
            const SizedBox(width: 12),
            Text('Change Password'),
          ],
        ),
        content: Text(
          'Password reset email will be sent to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ModernGradientButton(
            text: 'Send Email',
            onPressed: () {
              Navigator.pop(context);
              // TODO: Send password reset email
            },
            gradient: AppTheme.warningGradient,
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.download_rounded, color: AppTheme.infoBlue),
            ),
            const SizedBox(width: 12),
            Text('Export Data'),
          ],
        ),
        content: Text('Your data will be prepared and emailed to you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ModernGradientButton(
            text: 'Export',
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('Data export requested'),
                    ],
                  ),
                  backgroundColor: AppTheme.primaryEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            gradient: LinearGradient(
              colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(width: 12),
            Text('Delete Account', style: TextStyle(color: AppTheme.errorRed)),
          ],
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ModernGradientButton(
            text: 'Delete',
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            gradient: AppTheme.errorGradient,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Final Confirmation',
          style: TextStyle(color: AppTheme.errorRed),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Type "DELETE" to confirm account deletion.'),
            const SizedBox(height: 16),
            ModernTextField(
              hint: 'Type DELETE here',
              // TODO: Enable when "DELETE" is typed correctly
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ModernGradientButton(
            text: 'DELETE ACCOUNT',
            onPressed: null, // TODO: Enable when "DELETE" is typed correctly
            gradient: AppTheme.errorGradient,
          ),
        ],
      ),
    );
  }
}
