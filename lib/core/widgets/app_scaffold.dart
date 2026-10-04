import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_status_bar.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color backgroundColor;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool unfocusOnTap;
  final bool resizeToAvoidBottomInset;
  final bool isLoading;
  final String? loadingMessage;
  final Brightness statusBarIconBrightness;
  final Color statusBarColor;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundColor = Colors.white,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.unfocusOnTap = true,
    this.resizeToAvoidBottomInset = true,
    this.isLoading = false,
    this.loadingMessage,
    this.statusBarIconBrightness = Brightness.dark,
    this.statusBarColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    // Safe Area Handling (jika ada appBar, safeAreaTop biasanya sudah ditangani AppBar)
    content = SafeArea(
      top: appBar == null && safeAreaTop,
      bottom: safeAreaBottom,
      child: content,
    );

    // Loading overlay
    if (isLoading) {
      content = Stack(
        children: [
          content,
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                    ),
                  ),
                  if (loadingMessage != null && loadingMessage!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      loadingMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Dismiss keyboard on tap outside
    if (unfocusOnTap) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: content,
      );
    }

    return AppStatusBar(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: statusBarIconBrightness,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        body: content,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        drawer: drawer,
        endDrawer: endDrawer,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}
