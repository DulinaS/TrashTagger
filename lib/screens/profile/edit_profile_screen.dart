// lib/screens/profile/edit_profile_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../themes/app_theme.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _currentPhotoURL;
  bool _isLoading = false;
  bool _isUploading = false;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _photoController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: AnimationConstants.mediumDuration,
      vsync: this,
    );
    _photoController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    // Start animations
    Future.delayed(AnimationConstants.shortDelay, () {
      if (mounted) {
        _slideController.forward();
        _photoController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _photoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _currentPhotoURL = user.photoURL;
    }
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
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
                        'Choose Photo Source',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ModernCard(
                              onTap: () {
                                Navigator.pop(context);
                                _getImage(ImageSource.camera);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Camera',
                                      style: AppTheme.titleMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ModernCard(
                              onTap: () {
                                Navigator.pop(context);
                                _getImage(ImageSource.gallery);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.accentPurple,
                                            AppTheme.accentCoral,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.photo_library_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Gallery',
                                      style: AppTheme.titleMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 600,
        maxHeight: 600,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        if (_imageFile != null && await _imageFile!.exists()) {
          try {
            await _imageFile!.delete();
          } catch (e) {
            print('Could not delete previous image: $e');
          }
        }

        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error selecting image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not found');
      }

      String? photoURL = _currentPhotoURL;

      // Upload new photo if selected
      if (_imageFile != null) {
        setState(() => _isUploading = true);
        photoURL = await StorageService.uploadProfilePhoto(
          _imageFile!,
          currentUser.id,
        );
        setState(() => _isUploading = false);
      }

      // Update Firebase Auth profile
      final firebaseUser = authProvider.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(_nameController.text.trim());
        if (photoURL != null && photoURL != _currentPhotoURL) {
          await firebaseUser.updatePhotoURL(photoURL);
        }
      }

      // Update Firestore user document
      final updatedUser = UserModel(
        id: currentUser.id,
        name: _nameController.text.trim(),
        email: currentUser.email,
        photoURL: photoURL,
        totalPoints: currentUser.totalPoints,
        badges: currentUser.badges,
        level: currentUser.level,
        joinDate: currentUser.joinDate,
        lastActive: DateTime.now(),
        settings: currentUser.settings,
        stats: currentUser.stats,
      );

      await userProvider.updateUser(updatedUser);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: AppTheme.primaryEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackbar('Error updating profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    try {
      final email = _emailController.text;
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: AppTheme.primaryEmerald,
                ),
              ),
              const SizedBox(width: 12),
              Text('Password Reset Email Sent'),
            ],
          ),
          content: Text(
            'A password reset email has been sent to $email. Please check your inbox and follow the instructions.',
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
    } catch (e) {
      _showErrorSnackbar('Error sending password reset email: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: _isLoading
            ? ModernLoadingWidget(message: 'Updating profile...')
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Profile Photo Section
                      SlideInAnimation(
                        delay: AnimationConstants.microDelay,
                        child: _buildProfilePhotoSection(),
                      ),
                      const SizedBox(height: 24),

                      // Name Field
                      SlideInAnimation(
                        delay: AnimationConstants.shortDelay,
                        child: _buildNameField(),
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      SlideInAnimation(
                        delay: AnimationConstants.mediumDelay,
                        child: _buildEmailField(),
                      ),
                      const SizedBox(height: 24),

                      // Change Password Button
                      SlideInAnimation(
                        delay: AnimationConstants.longDelay,
                        child: _buildChangePasswordButton(),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      ScaleInAnimation(
                        delay: AnimationConstants.extraLongDelay,
                        child: _buildSaveButton(),
                      ),
                      const SizedBox(height: 24),

                      // Additional Info
                      SlideInAnimation(
                        delay: const Duration(milliseconds: 600),
                        child: _buildAdditionalInfo(),
                      ),
                    ],
                  ),
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
      elevation: 8,
      shadowColor: AppTheme.primaryEmerald.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryEmerald.withOpacity(0.2),
              AppTheme.accentPurple.withOpacity(0.15),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryEmerald.withOpacity(0.2),
                    AppTheme.accentPurple.withOpacity(0.15),
                  ],
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Edit Profile',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.only(
              left: 72,
              bottom: 16,
              right: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
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
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Profile Photo',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              ScaleInAnimation(
                delay: AnimationConstants.shortDelay,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryEmerald.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 58,
                    backgroundColor: Colors.transparent,
                    backgroundImage: _getProfileImage(),
                    child: _getProfileImage() == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: ScaleInAnimation(
                  delay: AnimationConstants.mediumDelay,
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.accentCoral, AppTheme.accentAmber],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCoral.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tap the camera icon to change your profile photo',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_currentPhotoURL != null && _currentPhotoURL!.isNotEmpty) {
      return NetworkImage(_currentPhotoURL!);
    }
    return null;
  }

  Widget _buildNameField() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Display Name',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _nameController,
            hint: 'Enter your display name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              if (value.trim().length > 30) {
                return 'Name must be less than 30 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
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
                child: Icon(
                  Icons.email_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Email Address',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _emailController,
            hint: 'Your email address',
            readOnly: true,
            fillColor: AppTheme.backgroundPrimary,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppTheme.infoBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Email cannot be changed. Contact support if needed.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.infoBlue,
                      fontWeight: FontWeight.w500,
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

  Widget _buildChangePasswordButton() {
    return ModernCard(
      onTap: _changePassword,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.warningGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send password reset email to your inbox',
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
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ModernGradientButton(
      text: 'Save Changes',
      onPressed: _isLoading ? null : _saveProfile,
      isLoading: _isLoading,
      icon: _isLoading ? null : Icons.save_rounded,
      gradient: AppTheme.primaryGradient,
      width: double.infinity,
    );
  }

  Widget _buildAdditionalInfo() {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    if (user == null) return SizedBox.shrink();

    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentPurple, AppTheme.accentCoral],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Account Information',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Member Since', _formatDate(user.joinDate)),
          _buildInfoRow('Total Points', user.totalPoints.toString()),
          _buildInfoRow('Current Level', user.level.toString()),
          _buildInfoRow('Badges Earned', user.badges.length.toString()),
          _buildInfoRow(
            'Reports Submitted',
            user.stats.reportsSubmitted.toString(),
          ),
          _buildInfoRow(
            'Cleanups Completed',
            user.stats.challengesCompleted.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryEmerald,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
