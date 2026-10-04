import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppStatusBar extends StatelessWidget {
  final Widget child;
  final Color statusBarColor;
  final Brightness statusBarIconBrightness;
  final Color? navigationBarColor;
  final Brightness navigationBarIconBrightness;

  const AppStatusBar({
    super.key,
    required this.child,
    this.statusBarColor = Colors.transparent,
    this.statusBarIconBrightness = Brightness.dark,
    this.navigationBarColor,
    this.navigationBarIconBrightness = Brightness.dark,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarIconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark, // iOS
        systemNavigationBarColor:
            navigationBarColor ?? Colors.white,
        systemNavigationBarIconBrightness: navigationBarIconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: child,
    );
  }
}
