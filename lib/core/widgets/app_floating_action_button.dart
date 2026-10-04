import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Core Widget Floating Action Button dengan desain modern Halala Food.
/// Mendukung FAB standar (icon-only) dan Extended FAB (icon + label teks).
class AppFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool isLoading;
  final Object? heroTag;
  final double borderRadius;

  const AppFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4.0,
    this.isLoading = false,
    this.heroTag,
    this.borderRadius = 16.0,
  }) : label = null;

  const AppFloatingActionButton.extended({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4.0,
    this.isLoading = false,
    this.heroTag,
    this.borderRadius = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.brandPrimary;
    final effectiveFg = foregroundColor ?? Colors.white;

    if (label != null) {
      // Extended FAB
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: effectiveBg.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: heroTag,
          onPressed: isLoading ? null : onPressed,
          tooltip: tooltip,
          backgroundColor: effectiveBg,
          foregroundColor: effectiveFg,
          elevation: elevation,
          highlightElevation: elevation + 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          icon: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
                  ),
                )
              : icon,
          label: Text(
            label!,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: effectiveFg,
              letterSpacing: 0.1,
            ),
          ),
        ),
      );
    }

    // Standard Circular / Rounded FAB
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: effectiveBg.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: isLoading ? null : onPressed,
        tooltip: tooltip,
        backgroundColor: effectiveBg,
        foregroundColor: effectiveFg,
        elevation: elevation,
        highlightElevation: elevation + 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
                ),
              )
            : icon,
      ),
    );
  }
}
