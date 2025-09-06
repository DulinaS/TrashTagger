// lib/widgets/common/custom_button.dart - Modern Design
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.gradient,
    this.padding,
    this.width,
    this.height = 56,
    this.borderRadius,
    this.boxShadow,
  }) : super(key: key);

  @override
  _CustomButtonState createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _handleTapEnd();
  }

  void _handleTapCancel() {
    _handleTapEnd();
  }

  void _handleTapEnd() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        widget.backgroundColor ?? AppTheme.primaryEmerald;
    final effectiveTextColor = widget.textColor ?? Colors.white;
    final effectiveGradient =
        widget.gradient ??
        (widget.isOutlined ? null : AppTheme.primaryGradient);
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(16);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: widget.isOutlined ? null : effectiveGradient,
              color: widget.isOutlined
                  ? Colors.transparent
                  : (effectiveGradient == null
                        ? effectiveBackgroundColor
                        : null),
              borderRadius: effectiveBorderRadius,
              border: widget.isOutlined
                  ? Border.all(
                      color: widget.onPressed != null && !widget.isLoading
                          ? AppTheme.primaryEmerald
                          : AppTheme.borderMedium,
                      width: 2,
                    )
                  : null,
              boxShadow: widget.isOutlined
                  ? null
                  : (widget.boxShadow ??
                        [
                          if (widget.onPressed != null && !widget.isLoading)
                            BoxShadow(
                              color: effectiveBackgroundColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                        ]),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                borderRadius: effectiveBorderRadius,
                child: Container(
                  padding:
                      widget.padding ??
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: _buildButtonContent(effectiveTextColor),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonContent(Color textColor) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isOutlined ? AppTheme.primaryEmerald : Colors.white,
            ),
          ),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            color: widget.isOutlined ? AppTheme.primaryEmerald : textColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: AppTheme.labelLarge.copyWith(
              color: widget.isOutlined ? AppTheme.primaryEmerald : textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Center(
      child: Text(
        widget.text,
        style: AppTheme.labelLarge.copyWith(
          color: widget.isOutlined ? AppTheme.primaryEmerald : textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Modern Floating Action Button Widget
class ModernFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String? heroTag;
  final Color? backgroundColor;
  final LinearGradient? gradient;
  final double size;
  final bool extended;

  const ModernFAB({
    Key? key,
    required this.onPressed,
    required this.child,
    this.heroTag,
    this.backgroundColor,
    this.gradient,
    this.size = 56,
    this.extended = false,
  }) : super(key: key);

  @override
  _ModernFABState createState() => _ModernFABState();
}

class _ModernFABState extends State<ModernFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppTheme.primaryGradient;
    final effectiveBackgroundColor =
        widget.backgroundColor ?? AppTheme.primaryEmerald;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.extended ? null : widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: BorderRadius.circular(
                widget.extended ? 28 : widget.size / 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: effectiveBackgroundColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                borderRadius: BorderRadius.circular(
                  widget.extended ? 28 : widget.size / 2,
                ),
                child: Container(
                  padding: widget.extended
                      ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                      : null,
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Icon Button with Modern Design
class ModernIconButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const ModernIconButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
  }) : super(key: key);

  @override
  _ModernIconButtonState createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<ModernIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        widget.backgroundColor ?? AppTheme.backgroundSecondary;
    final effectiveIconColor = widget.iconColor ?? AppTheme.textPrimary;

    Widget button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: effectiveIconColor,
                    size: widget.iconSize,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
