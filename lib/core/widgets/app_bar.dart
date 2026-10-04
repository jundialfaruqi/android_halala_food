import 'package:flutter/material.dart';
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
  final bool showBottomBorder;

  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showLogo = false,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bottom,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.brandEspresso,
    this.centerTitle = true,
    this.elevation = 0,
    this.showBottomBorder = true,
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
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: foregroundColor,
        tooltip: 'Kembali',
        onPressed: () => Navigator.of(context).maybePop(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showBottomBorder
            ? const Border(
                bottom: BorderSide(
                  color: AppColors.brandBorder,
                  width: 1,
                ),
              )
            : null,
      ),
      child: AppBar(
        title: computedTitle,
        centerTitle: centerTitle,
        leading: leadingWidget,
        automaticallyImplyLeading: false,
        actions: actions,
        bottom: bottom,
        backgroundColor: Colors.transparent,
        foregroundColor: foregroundColor,
        elevation: elevation,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
