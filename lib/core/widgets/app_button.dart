import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final AppButtonVariant variant;
  final double? width;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.width = double.infinity,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.textColor,
  });

  const AppButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.textColor,
  }) : variant = AppButtonVariant.outline;

  const AppButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.textColor,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 40.0,
    this.borderRadius = 8.0,
    this.backgroundColor,
    this.textColor,
  }) : variant = AppButtonVariant.text;

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = backgroundColor ?? _getDefaultBgColor();
    final effectiveTextColor = textColor ?? _getDefaultTextColor();

    Widget child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.primary
                    ? Colors.white
                    : AppColors.brandPrimary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: effectiveTextColor,
                  ),
                ),
              ),
            ],
          );

    final buttonStyle = switch (variant) {
      AppButtonVariant.outline => OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.brandBorder),
          backgroundColor: effectiveBgColor,
          foregroundColor: effectiveTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          minimumSize: Size(width ?? 0, height),
        ),
      AppButtonVariant.text => TextButton.styleFrom(
          foregroundColor: effectiveTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          minimumSize: Size(width ?? 0, height),
        ),
      _ => ElevatedButton.styleFrom(
          backgroundColor: effectiveBgColor,
          foregroundColor: effectiveTextColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          minimumSize: Size(width ?? 0, height),
        ),
    };

    return SizedBox(
      width: width,
      height: height,
      child: switch (variant) {
        AppButtonVariant.outline => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: child,
          ),
        AppButtonVariant.text => TextButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: child,
          ),
        _ => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: child,
          ),
      },
    );
  }

  Color _getDefaultBgColor() {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.brandPrimary;
      case AppButtonVariant.secondary:
        return AppColors.brandSoftCream;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return Colors.transparent;
    }
  }

  Color _getDefaultTextColor() {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;
      case AppButtonVariant.secondary:
        return AppColors.brandPrimary;
      case AppButtonVariant.outline:
        return AppColors.brandEspresso;
      case AppButtonVariant.text:
        return AppColors.brandPrimary;
    }
  }
}
