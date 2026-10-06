import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widget Card inti (core) Halala Food dengan berbagai varian styling:
/// - [AppCard]: Card standar dengan bayangan tipis lembut dan border halus.
/// - [AppCard.soft]: Card berlatar krem hangat lembut (brandSoftCreamLight).
/// - [AppCard.outlined]: Card bergaya clean outline tanpa bayangan.
/// - [AppCard.stacked]: Card dengan efek tumpukan 3 lapis (stacked 3-tier deck).
/// - [AppCard.header]: Card lengkap dengan header terintegrasi (title, subtitle, action).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  // Mode internal
  final bool _isStacked;
  final double _stackInsetHorizontal;
  final double _stackOffsetVertical;
  final bool stackAtTop;
  final bool isGlass;

  /// Card standar (#ffffff, tanpa shadow, tanpa border)
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.borderRadius = 16.0,
    this.onTap,
    this.onLongPress,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  })  : _isStacked = false,
        _stackInsetHorizontal = 0,
        _stackOffsetVertical = 0,
        stackAtTop = false,
        isGlass = false;

  /// Card bernuansa krem lembut khas Halala Food
  const AppCard.soft({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor = AppColors.brandSoftCreamLight,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.borderRadius = 16.0,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
  })  : _isStacked = false,
        _stackInsetHorizontal = 0,
        _stackOffsetVertical = 0,
        stackAtTop = false,
        isGlass = false,
        boxShadow = null;

  /// Card minimalis bergaris tepi tanpa efek bayangan
  const AppCard.outlined({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.borderRadius = 16.0,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
  })  : _isStacked = false,
        _stackInsetHorizontal = 0,
        _stackOffsetVertical = 0,
        stackAtTop = false,
        isGlass = false,
        boxShadow = null;

  /// Card dengan efek tumpukan 3 layer (3-card stacked deck effect) lengkap dengan shadow
  const AppCard.stacked({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.borderRadius = 16.0,
    this.onTap,
    this.onLongPress,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
    double stackInsetHorizontal = 13.0,
    double stackOffsetVertical = 8.5,
    this.stackAtTop = false,
    this.isGlass = true,
  })  : _isStacked = true,
        _stackInsetHorizontal = stackInsetHorizontal,
        _stackOffsetVertical = stackOffsetVertical;

  /// Card yang dilengkapi dengan section header judul, icon, dan action
  factory AppCard.header({
    Key? key,
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
    EdgeInsetsGeometry? margin,
    Color backgroundColor = Colors.white,
    Color borderColor = Colors.transparent,
    double borderWidth = 0.0,
    double borderRadius = 16.0,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return AppCard(
      key: key,
      margin: margin,
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: borderRadius,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, color: AppColors.brandBorder),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }

  static final List<BoxShadow> _stackedFrontShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> _stackedFrontShadowTop = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, -2),
    ),
  ];

  Widget _buildCardContainer({bool isTopStacked = false}) {
    List<BoxShadow>? effectiveShadow = boxShadow;
    if (effectiveShadow == null && _isStacked) {
      effectiveShadow =
          isTopStacked ? _stackedFrontShadowTop : _stackedFrontShadow;
    }

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildDeckLayer({
    required double borderRadius,
    required Color fallbackColor,
    required double blurSigma,
    required double bgOpacity,
    required double borderOpacity,
    required List<BoxShadow> shadow,
  }) {
    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: fallbackColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderWidth > 0
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
          boxShadow: shadow,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: bgOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: borderWidth > 0
                  ? Border.all(
                      color: Colors.white.withValues(alpha: borderOpacity),
                      width: borderWidth,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStacked) {
      return Container(
        margin: margin,
        child: _buildCardContainer(),
      );
    }

    // Tampilan Stack 3-Card Deck Effect
    final peak = _stackOffsetVertical * 2;

    if (stackAtTop) {
      return Container(
        margin: margin,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Layer 3: Card Paling Belakang / Teratas (posisi paling atas)
            Positioned(
              top: 0,
              bottom: _stackOffsetVertical * 2,
              left: _stackInsetHorizontal * 2,
              right: _stackInsetHorizontal * 2,
              child: _buildDeckLayer(
                borderRadius: borderRadius,
                fallbackColor: AppColors.brandSoftCreamLight,
                blurSigma: 12.0,
                bgOpacity: 0.35,
                borderOpacity: 0.60,
                shadow: boxShadow ?? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),

            // Layer 2: Card Tengah
            Positioned(
              top: _stackOffsetVertical,
              bottom: _stackOffsetVertical,
              left: _stackInsetHorizontal,
              right: _stackInsetHorizontal,
              child: _buildDeckLayer(
                borderRadius: borderRadius,
                fallbackColor: Colors.white,
                blurSigma: 14.0,
                bgOpacity: 0.50,
                borderOpacity: 0.75,
                shadow: boxShadow ?? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),

            // Layer 1: Card Terdepan (Membungkus Konten Asli)
            Padding(
              padding: EdgeInsets.only(top: peak),
              child: _buildCardContainer(isTopStacked: true),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: margin,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Layer 3: Card Paling Belakang / Terbawah
          Positioned(
            top: _stackOffsetVertical * 2,
            bottom: 0,
            left: _stackInsetHorizontal * 2,
            right: _stackInsetHorizontal * 2,
            child: _buildDeckLayer(
              borderRadius: borderRadius,
              fallbackColor: AppColors.brandSoftCreamLight,
              blurSigma: 12.0,
              bgOpacity: 0.35,
              borderOpacity: 0.60,
              shadow: boxShadow ?? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),

          // Layer 2: Card Tengah
          Positioned(
            top: _stackOffsetVertical,
            bottom: _stackOffsetVertical,
            left: _stackInsetHorizontal,
            right: _stackInsetHorizontal,
            child: _buildDeckLayer(
              borderRadius: borderRadius,
              fallbackColor: Colors.white,
              blurSigma: 14.0,
              bgOpacity: 0.50,
              borderOpacity: 0.75,
              shadow: boxShadow ?? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          // Layer 1: Card Terdepan (Membungkus Konten Asli)
          Padding(
            padding: EdgeInsets.only(bottom: peak),
            child: _buildCardContainer(),
          ),
        ],
      ),
    );
  }
}
