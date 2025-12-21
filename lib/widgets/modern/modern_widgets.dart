// lib/widgets/modern/modern_widgets.dart - Modern UI Components (Fixed Overflow Issues)
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';

/// Modern gradient button with enhanced effects
class ModernGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final EdgeInsets? padding;
  final double? width;
  final double borderRadius;

  const ModernGradientButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.padding,
    this.width,
    this.borderRadius = 16,
  }) : super(key: key);

  @override
  _ModernGradientButtonState createState() => _ModernGradientButtonState();
}

class _ModernGradientButtonState extends State<ModernGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.buttonPress,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _resetButton();
  }

  void _onTapCancel() {
    _resetButton();
  }

  void _resetButton() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppTheme.primaryGradient;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              padding:
                  widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: widget.isOutlined ? null : gradient,
                border: widget.isOutlined
                    ? Border.all(color: gradient.colors.first, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: widget.isOutlined
                    ? null
                    : [
                        BoxShadow(
                          color: gradient.colors.first.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isOutlined
                              ? gradient.colors.first
                              : Colors.white,
                        ),
                      ),
                    )
                  else ...[
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.isOutlined
                            ? gradient.colors.first
                            : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        style: AppTheme.labelLarge.copyWith(
                          color: widget.isOutlined
                              ? gradient.colors.first
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ModernSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final bool showFilter;

  const ModernSearchBar({
    Key? key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onFilterTap,
    this.showFilter = true,
  }) : super(key: key);

  @override
  _ModernSearchBarState createState() => _ModernSearchBarState();
}

class _ModernSearchBarState extends State<ModernSearchBar> {
  final _controller = TextEditingController();
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? AppTheme.primaryEmerald : AppTheme.borderLight,
          width: _isFocused ? 2 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.primaryEmerald.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: _isFocused ? AppTheme.primaryEmerald : AppTheme.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Focus(
              onFocusChange: (focused) {
                setState(() => _isFocused = focused);
              },
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                style: AppTheme.bodyMedium,
              ),
            ),
          ),
          if (widget.showFilter) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: widget.onFilterTap,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primaryEmerald,
                  size: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Modern card with glassmorphism effect
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final bool enableGlassmorphism;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final Border? border;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.enableGlassmorphism = false,
    this.backgroundColor,
    this.boxShadow,
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: enableGlassmorphism
            ? null
            : (backgroundColor ?? AppTheme.backgroundSecondary),
        gradient: enableGlassmorphism
            ? AppTheme.glassmorphismDecoration.gradient
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            border ??
            (enableGlassmorphism
                ? AppTheme.glassmorphismDecoration.border
                : Border.all(color: AppTheme.borderLight)),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: AppTheme.shadowLight,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Modern input field with enhanced styling
class ModernTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLines;
  final bool enableFloatingLabel;
  final bool enabled;
  final Color? fillColor;
  final ValueChanged<String>? onChanged;

  const ModernTextField({
    Key? key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.enableFloatingLabel = true,
    this.enabled = true,
    this.fillColor,
    this.onChanged,
  }) : super(key: key);

  @override
  _ModernTextFieldState createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _borderColorAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.fastDuration,
      vsync: this,
    );
    _borderColorAnimation = ColorTween(
      begin: AppTheme.borderLight,
      end: AppTheme.primaryEmerald,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && !widget.enableFloatingLabel) ...[
          Text(
            widget.label!,
            style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: _borderColorAnimation,
          builder: (context, child) {
            return TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onTap: widget.onTap,
              readOnly: widget.readOnly,
              maxLines: widget.maxLines,
              enabled: widget.enabled,
              style: AppTheme.bodyLarge,
              onChanged: widget.onChanged,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: widget.enableFloatingLabel ? widget.label : null,
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon != null
                    ? Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryEmerald.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.prefixIcon,
                          color: AppTheme.primaryEmerald,
                          size: 20,
                        ),
                      )
                    : null,
                suffixIcon: widget.suffixIcon,
                filled: true,
                fillColor: widget.fillColor ?? AppTheme.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _borderColorAnimation.value!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryEmerald,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.errorRed),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                labelStyle: AppTheme.bodyMedium.copyWith(
                  color: _isFocused
                      ? AppTheme.primaryEmerald
                      : AppTheme.textTertiary,
                ),
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              focusNode: FocusNode()
                ..addListener(() {
                  setState(() => _isFocused = FocusScope.of(context).hasFocus);
                  if (_isFocused) {
                    _controller.forward();
                  } else {
                    _controller.reverse();
                  }
                }),
            );
          },
        ),
      ],
    );
  }
}

/// Modern chip with enhanced styling - FIXED OVERFLOW
class ModernChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final Color? unselectedColor;
  final LinearGradient? gradient;
  final double? width;

  const ModernChip({
    Key? key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.selectedColor,
    this.unselectedColor,
    this.gradient,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected;
    final backgroundColor = isSelected
        ? (selectedColor ?? AppTheme.primaryEmerald)
        : (unselectedColor ?? AppTheme.backgroundSecondary);

    return Container(
      width: width,
      constraints: BoxConstraints(
        minHeight: 44, // Ensure minimum touch target
        maxWidth: width ?? double.infinity,
      ),
      decoration: BoxDecoration(
        gradient: isSelected && gradient != null ? gradient : null,
        color: gradient == null ? backgroundColor : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (selectedColor ?? AppTheme.primaryEmerald)
              : AppTheme.borderLight,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: (selectedColor ?? AppTheme.primaryEmerald).withOpacity(
                    0.3,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : AppTheme.primaryEmerald,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTheme.labelMedium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.primaryEmerald,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern loading widget
class ModernLoadingWidget extends StatelessWidget {
  final String message;
  final Color? color;
  final double size;

  const ModernLoadingWidget({
    Key? key,
    this.message = 'Loading...',
    this.color,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulseAnimation(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.6,
                  height: size * 0.6,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TypewriterAnimation(
            text: message,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
            duration: const Duration(milliseconds: 1000),
          ),
        ],
      ),
    );
  }
}

/// Modern status badge - FIXED OVERFLOW
class ModernStatusBadge extends StatelessWidget {
  final String status;
  final String? customText;
  final IconData? icon;
  final Color? color;
  final bool showPulse;

  const ModernStatusBadge({
    Key? key,
    required this.status,
    this.customText,
    this.icon,
    this.color,
    this.showPulse = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = color ?? AppTheme.getStatusColor(status);
    final statusText = customText ?? _getStatusText(status);
    final statusIcon = icon ?? _getStatusIcon(status);

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: 200, // Prevent overflow
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusText,
              style: AppTheme.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );

    return showPulse ? PulseAnimation(child: badge) : badge;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'verified':
        return 'VERIFIED';
      case 'cleaning':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'rejected':
        return 'REJECTED';
      case 'disputed':
        return 'DISPUTED';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'disputed':
        return Icons.warning_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}

/// Modern empty state widget
/// Modern empty state widget - FIXED OVERFLOW ISSUE
class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final LinearGradient? gradient;

  const ModernEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available space and adjust component sizes accordingly
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Scale components based on available space
        final isCompact = availableHeight < 400;
        final iconSize = isCompact ? 80.0 : 120.0;
        final iconRadius = isCompact ? 20.0 : 30.0;
        final spacing = isCompact ? 16.0 : 32.0;
        final smallSpacing = isCompact ? 8.0 : 12.0;

        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: availableHeight > 0 ? availableHeight * 0.6 : 300,
                maxWidth: availableWidth > 0 ? availableWidth - 80 : 300,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 20.0 : 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleInAnimation(
                        child: Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            gradient: gradient ?? AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(iconRadius),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (gradient?.colors.first ??
                                            AppTheme.primaryEmerald)
                                        .withOpacity(0.3),
                                blurRadius: isCompact ? 12 : 20,
                                offset: Offset(0, isCompact ? 4 : 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            size: isCompact ? 40 : 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing),
                      SlideInAnimation(
                        beginOffset: const Offset(0, 0.2),
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          title,
                          style:
                              (isCompact
                                      ? AppTheme.titleLarge
                                      : AppTheme.headlineMedium)
                                  .copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: smallSpacing),
                      SlideInAnimation(
                        beginOffset: const Offset(0, 0.2),
                        delay: const Duration(milliseconds: 300),
                        child: Text(
                          message,
                          style: isCompact
                              ? AppTheme.bodySmall
                              : AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (actionText != null && onAction != null) ...[
                        SizedBox(height: spacing),
                        ScaleInAnimation(
                          delay: const Duration(milliseconds: 400),
                          child: ModernGradientButton(
                            text: actionText!,
                            onPressed: onAction,
                            icon: Icons.add_rounded,
                            gradient: gradient ?? AppTheme.primaryGradient,
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 16 : 24,
                              vertical: isCompact ? 12 : 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
