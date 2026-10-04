import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global RouteObserver untuk melacak transisi rute dan menyinkronkan status bar secara instan
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

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

  /// Terapkan gaya status bar gelap (ikon hitam) secara instan di frame ke-0
  static void setDark({Color statusBarColor = Colors.transparent}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: Brightness.dark, // Android: icon hitam
        statusBarBrightness: Brightness.light,    // iOS: icon hitam
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  /// Terapkan gaya status bar terang (ikon putih) secara instan di frame ke-0 (untuk Home Screen)
  static void setLight({Color statusBarColor = Colors.transparent}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: Brightness.light, // Android: icon putih
        statusBarBrightness: Brightness.dark,     // iOS: icon putih
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

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
