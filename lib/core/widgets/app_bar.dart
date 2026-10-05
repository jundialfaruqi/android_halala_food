import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

class AppAppBar extends StatefulWidget implements PreferredSizeWidget {
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
  final bool hasShadow;
  final bool alwaysShowShadow;
  final bool showBottomBorder;
  final List<BoxShadow>? customShadow;
  final double? titleSpacing;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final ScrollNotificationPredicate? notificationPredicate;

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
    this.scrolledUnderElevation = 0,
    this.shadowColor,
    this.surfaceTintColor = Colors.transparent,
    this.hasShadow = true,
    this.alwaysShowShadow = false,
    this.showBottomBorder = false,
    this.customShadow,
    this.titleSpacing,
    this.systemOverlayStyle,
    this.notificationPredicate,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  State<AppAppBar> createState() => _AppAppBarState();
}

class _AppAppBarState extends State<AppAppBar> {
  ScrollNotificationObserverState? _scrollNotificationObserver;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    _scrollNotificationObserver?.addListener(_handleScrollNotification);
  }

  @override
  void dispose() {
    if (_scrollNotificationObserver != null) {
      _scrollNotificationObserver!.removeListener(_handleScrollNotification);
      _scrollNotificationObserver = null;
    }
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      final predicate = widget.notificationPredicate ??
          (ScrollNotification n) => n.depth == 0;
      if (predicate(notification)) {
        final ScrollMetrics metrics = notification.metrics;
        final bool isScrolled;
        switch (metrics.axisDirection) {
          case AxisDirection.up:
            isScrolled = metrics.extentAfter > 0;
            break;
          case AxisDirection.down:
          default:
            isScrolled = metrics.extentBefore > 0;
            break;
        }

        if (_scrolledUnder != isScrolled) {
          setState(() {
            _scrolledUnder = isScrolled;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? computedTitle = widget.titleWidget;

    if (computedTitle == null) {
      if (widget.showLogo) {
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
            if (widget.title != null && widget.title!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                widget.title!,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.foregroundColor,
                ),
              ),
            ],
          ],
        );
      } else if (widget.title != null) {
        computedTitle = Text(
          widget.title!,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: widget.foregroundColor,
          ),
        );
      }
    }

    Widget? leadingWidget = widget.leading;
    if (leadingWidget == null &&
        widget.automaticallyImplyLeading &&
        Navigator.of(context).canPop()) {
      leadingWidget = IconButton(
        icon: const Icon(TablerIcons.chevron_left, size: 22),
        color: widget.foregroundColor,
        tooltip: 'Kembali',
        onPressed: () => Navigator.of(context).maybePop(),
      );
    }

    final appBarWidget = AppBar(
      title: computedTitle,
      centerTitle: widget.centerTitle,
      titleSpacing: widget.titleSpacing,
      leading: leadingWidget,
      automaticallyImplyLeading: false,
      actions: widget.actions,
      bottom: widget.bottom,
      backgroundColor: widget.backgroundColor,
      foregroundColor: widget.foregroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: widget.surfaceTintColor,
      systemOverlayStyle: widget.systemOverlayStyle ??
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Icon hitam di Android
            statusBarBrightness: Brightness.light,    // Icon hitam di iOS
          ),
    );

    final bool shouldShowShadow =
        widget.hasShadow && (_scrolledUnder || widget.alwaysShowShadow);

    final List<BoxShadow>? computedShadow = shouldShowShadow
        ? (widget.customShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ])
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        boxShadow: computedShadow,
        border: widget.showBottomBorder
            ? const Border(
                bottom: BorderSide(
                  color: AppColors.brandBorder,
                  width: 1,
                ),
              )
            : null,
      ),
      child: appBarWidget,
    );
  }
}
