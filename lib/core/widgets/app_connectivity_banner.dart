import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';
import '../utils/connectivity_service.dart';

/// Widget Wrapper Global yang memantau koneksi internet secara reaktif di seluruh halaman.
/// Menampilkan banner merah solid yang menempel penuh (edge-to-edge) tepat di bawah status bar
/// dan mendorong konten halaman ke bawah sehingga tidak menutupi informasi penting (seperti info user di Home).
class AppConnectivityWrapper extends ConsumerWidget {
  final Widget child;

  const AppConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStatusProvider);
    final isConnected = connectivityAsync.maybeWhen(
      data: (results) => results.hasActiveConnection,
      orElse: () => true,
    );

    if (isConnected) {
      return child;
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.error,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Area Status Bar menyatu merah solid
            Container(
              height: topPadding,
              color: AppColors.error,
            ),

            // Banner Alert Merah Solid Menempel Penuh (Kiri, Kanan, & Bawah Status Bar)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.error,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    TablerIcons.wifi_off,
                    size: 17,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Tidak Ada Koneksi Internet',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Konten halaman utama (didukung MediaQuery.removePadding agar info user tetap pas)
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
