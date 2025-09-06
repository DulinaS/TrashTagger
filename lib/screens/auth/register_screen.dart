// lib/screens/auth/register_screen.dart - Modern Vibrant Design
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/custom_button.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  late AnimationController _backgroundController;
  late AnimationController _formController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );
    _formController = AnimationController(
      duration: AnimationConstants.slowDuration,
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_backgroundController);

    _backgroundController.repeat();

    // Delayed form animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppTheme.accentPurple.withOpacity(0.1),
              AppTheme.primaryTeal.withOpacity(0.05),
              AppTheme.backgroundPrimary,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated Background Elements
            _buildAnimatedBackground(),

            // Main Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Header with Back Button
                    SlideInAnimation(
                      delay: AnimationConstants.shortDelay,
                      child: _buildHeader(),
                    ),

                    const SizedBox(height: 40),

                    // Registration Form
                    SlideInAnimation(
                      delay: AnimationConstants.mediumDelay,
                      beginOffset: const Offset(0, 0.5),
                      child: _buildRegistrationForm(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Floating Circles with different timing
            Positioned(
              top: 150 + (40 * _backgroundAnimation.value),
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentPurple.withOpacity(0.1),
                      AppTheme.accentCoral.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 400 - (20 * _backgroundAnimation.value),
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryTeal.withOpacity(0.08),
                      AppTheme.primaryEmerald.withOpacity(0.04),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 200 + (30 * _backgroundAnimation.value),
              left: -50,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentAmber.withOpacity(0.1),
                      AppTheme.warningAmber.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Navigation and Logo Row
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryEmerald.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48), // Balance the back button
          ],
        ),
        const SizedBox(height: 24),

        // Title and Subtitle
        Text(
          'Join TrashTagger',
          style: AppTheme.displayMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Start making a difference in your community',
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Account',
              style: AppTheme.headlineLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please fill in your information to get started',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Name Field
            _buildModernTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              prefixIcon: Icons.person_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                if (value.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Email Field
            _buildModernTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email address',
              prefixIcon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password Field
            _buildModernTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a strong password',
              prefixIcon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppTheme.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Confirm Password Field
            _buildModernTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppTheme.textTertiary,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Terms and Conditions
            _buildTermsCheckbox(),
            const SizedBox(height: 32),

            // Register Button
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return _buildGradientButton(
                  text: 'Create Account',
                  isLoading: authProvider.isLoading,
                  onPressed: _agreedToTerms
                      ? () => _handleRegister(context)
                      : null,
                  gradient: _agreedToTerms
                      ? AppTheme.primaryGradient
                      : LinearGradient(
                          colors: [
                            AppTheme.textTertiary,
                            AppTheme.textTertiary,
                          ],
                        ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Error Message
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                if (authProvider.error != null) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.errorRed.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_rounded,
                          color: AppTheme.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authProvider.error!,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 24),

            // Login Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account? ', style: AppTheme.bodyMedium),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Sign In',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.primaryEmerald,
                      fontWeight: FontWeight.w600,
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryEmerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(prefixIcon, color: AppTheme.primaryEmerald, size: 20),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.backgroundPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.primaryEmerald, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.errorRed),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          child: Transform.scale(
            scale: 1.1,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (value) =>
                  setState(() => _agreedToTerms = value ?? false),
              activeColor: AppTheme.primaryEmerald,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTheme.bodyMedium,
              children: [
                TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryEmerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryEmerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' of TrashTagger'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String text,
    required bool isLoading,
    required VoidCallback? onPressed,
    required LinearGradient gradient,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: AppTheme.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.clearError();

      final success = await authProvider.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (success) {
        Navigator.pop(context);
      }
    }
  }
}
