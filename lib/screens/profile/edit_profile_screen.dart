import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _currentPhotoURL;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Choose Photo Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery);
                  },
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
        imageQuality: 70, // Reduce quality to save memory
        maxWidth: 600, // Reduce max dimensions
        maxHeight: 600,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        // Dispose previous image file if exists
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
        email: currentUser.email, // Email can't be changed here
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
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.primaryGreen,
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
          title: Text('Password Reset Email Sent'),
          content: Text(
            'A password reset email has been sent to $email. Please check your inbox and follow the instructions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
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
      SnackBar(content: Text(message), backgroundColor: AppTheme.dangerRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Edit Profile'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'SAVE',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? LoadingWidget(message: 'Updating profile...')
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Photo Section
                    _buildProfilePhotoSection(),
                    SizedBox(height: 32),

                    // Name Field
                    _buildNameField(),
                    SizedBox(height: 16),

                    // Email Field (Read-only)
                    _buildEmailField(),
                    SizedBox(height: 24),

                    // Change Password Button
                    _buildChangePasswordButton(),
                    SizedBox(height: 24),

                    // Save Button
                    _buildSaveButton(),
                    SizedBox(height: 16),

                    // Additional Info
                    _buildAdditionalInfo(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  backgroundImage: _getProfileImage(),
                  child: _getProfileImage() == null
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: AppTheme.primaryGreen,
                        )
                      : null,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Tap the camera icon to change your profile photo',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display Name',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your display name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
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
      ),
    );
  }

  Widget _buildEmailField() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Address',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Your email address',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: AppTheme.lightGreen.withOpacity(0.1),
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Email cannot be changed. Contact support if needed.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordButton() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Security',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 12),
            InkWell(
              onTap: _changePassword,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_reset, color: AppTheme.primaryGreen),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change Password', style: AppTheme.labelMedium),
                          SizedBox(height: 4),
                          Text(
                            'Send password reset email',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: 'Save Changes',
        onPressed: _isLoading ? null : _saveProfile,
        isLoading: _isLoading,
        icon: Icons.save,
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    if (user == null) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('Member Since', _formatDate(user.joinDate)),
            SizedBox(height: 8),
            _buildInfoRow('Total Points', user.totalPoints.toString()),
            SizedBox(height: 8),
            _buildInfoRow('Current Level', user.level.toString()),
            SizedBox(height: 8),
            _buildInfoRow('Badges Earned', user.badges.length.toString()),
            SizedBox(height: 8),
            _buildInfoRow(
              'Reports Submitted',
              user.stats.reportsSubmitted.toString(),
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              'Cleanups Completed',
              user.stats.challengesCompleted.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: AppTheme.labelMedium.copyWith(color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
