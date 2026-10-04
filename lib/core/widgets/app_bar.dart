import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showLogo;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool centerTitle;
  final double elevation;
  final double scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final bool showBottomBorder;
  final double? titleSpacing;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showLogo = false,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bottom,
    this.backgroundColor = Colors.white,
    this.foregroundColor = AppColors.brandEspresso,
    this.centerTitle = false,
    this.elevation = 0,
    this.scrolledUnderElevation = 3.0,
    this.shadowColor,
    this.surfaceTintColor = Colors.transparent,
    this.showBottomBorder = false,
    this.titleSpacing,
    this.systemOverlayStyle,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    Widget? computedTitle = titleWidget;

    if (computedTitle == null) {
      if (showLogo) {
        computedTitle = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.logo,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.storefront_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
            if (title != null && title!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                title!,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: foregroundColor,
                ),
              ),
            ],
          ],
        );
      } else if (title != null) {
        computedTitle = Text(
          title!,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: foregroundColor,
          ),
        );
      }
    }

    Widget? leadingWidget = leading;
    if (leadingWidget == null &&
        automaticallyImplyLeading &&
        Navigator.of(context).canPop()) {
      leadingWidget = IconButton(
        icon: const Icon(TablerIcons.chevron_left, size: 22),
        color: foregroundColor,
        tooltip: 'Kembali',
        onPressed: () => Navigator.of(context).maybePop(),
      );
    }

    final appBarWidget = AppBar(
      title: computedTitle,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      leading: leadingWidget,
      automaticallyImplyLeading: false,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColor ?? Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: surfaceTintColor,
      systemOverlayStyle: systemOverlayStyle ??
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Icon hitam di Android
            statusBarBrightness: Brightness.light,    // Icon hitam di iOS
          ),
    );

    if (showBottomBorder) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.brandBorder,
              width: 1,
            ),
          ),
        ),
        child: appBarWidget,
      );
    }

    return appBarWidget;
  }
}
