import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Hasil pengecekan keamanan perangkat.
class SecurityCheckResult {
  final bool isCompromised;
  final bool isDevMode;
  final bool isMockLocation;

  const SecurityCheckResult({
    this.isCompromised = false,
    this.isDevMode = false,
    this.isMockLocation = false,
  });

  static const SecurityCheckResult safe = SecurityCheckResult(
    isCompromised: false,
    isDevMode: false,
    isMockLocation: false,
  );

  String get title {
    if (isDevMode && isMockLocation) {
      return 'Peringatan Keamanan Perangkat';
    } else if (isMockLocation) {
      return 'Lokasi Palsu Terdeteksi';
    } else {
      return 'Mode Pengembang Aktif';
    }
  }

  String get message {
    if (isDevMode && isMockLocation) {
      return 'Aplikasi mendeteksi Mode Pengembang dan Fake GPS (Lokasi Tiruan) aktif pada perangkat Anda.\n\nDemi keamanan akun dan integritas transaksi, silakan matikan Mode Pengembang serta aplikasi Fake GPS di pengaturan perangkat Anda, lalu buka kembali aplikasi.';
    } else if (isMockLocation) {
      return 'Aplikasi mendeteksi penggunaan Fake GPS atau Lokasi Tiruan (Mock Location).\n\nDemi akurasi titik lokasi toko dan pengantaran, silakan matikan aplikasi Fake GPS dan Mode Pengembang di pengaturan perangkat Anda, lalu buka kembali aplikasi.';
    } else {
      return 'Developer mode aktif, silakan matikan developer mode di pengaturan perangkat Anda lalu buka kembali aplikasi.';
    }
  }
}

/// Service pusat untuk mendeteksi Developer Mode dan Mock GPS.
/// Hanya aktif di Build Mode Release (`kReleaseMode == true`).
class AppSecurityService {
  static const MethodChannel _channel = MethodChannel('com.halala.food/security');

  /// Flag pengujian unit test untuk memaksa proteksi aktif meskipun dalam mode debug/test.
  static bool forceEnabledForTesting = false;

  /// Notifier status pelanggaran keamanan global untuk reaktivitas UI.
  static final ValueNotifier<SecurityCheckResult?> violationNotifier =
      ValueNotifier<SecurityCheckResult?>(null);

  /// Menentukan apakah proteksi keamanan aktif.
  static bool get isProtectionActive => kReleaseMode || forceEnabledForTesting;

  /// Memeriksa apakah Developer Options / USB Debugging aktif di Android.
  static Future<bool> isDevModeEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? isDev = await _channel.invokeMethod<bool>('isDevModeEnabled');
      return isDev ?? false;
    } on PlatformException catch (e) {
      debugPrint('[SecurityService] Gagal cek dev mode: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa apakah Mock Location / Fake GPS aktif di Android.
  static Future<bool> isMockLocationEnabled() async {
    if (!Platform.isAndroid) return false;

    // 1. Cek melalui Native Channel (Settings & LastKnownLocation isMock)
    try {
      final bool? isMockNative =
          await _channel.invokeMethod<bool>('isMockLocationEnabled');
      if (isMockNative == true) return true;
    } catch (_) {}

    // 2. Cek melalui Geolocator jika izin lokasi sudah tersedia
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && lastPos.isMocked) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Memeriksa keseluruhan kondisi keamanan perangkat (Dev Mode & Mock GPS).
  static Future<SecurityCheckResult> checkSecurity() async {
    if (!isProtectionActive) {
      return SecurityCheckResult.safe;
    }

    final devMode = await isDevModeEnabled();
    final mockGps = await isMockLocationEnabled();

    if (devMode || mockGps) {
      final result = SecurityCheckResult(
        isCompromised: true,
        isDevMode: devMode,
        isMockLocation: mockGps,
      );
      violationNotifier.value = result;
      return result;
    }

    return SecurityCheckResult.safe;
  }

  /// Melaporkan jika saat runtime terdeteksi lokasi palsu dari sensor/geolocator.
  static void reportMockGpsDetected() {
    if (!isProtectionActive) return;

    final current = violationNotifier.value;
    violationNotifier.value = SecurityCheckResult(
      isCompromised: true,
      isDevMode: current?.isDevMode ?? false,
      isMockLocation: true,
    );
  }

  /// Memaksa keluar / kill aplikasi secara tuntas dari OS.
  static Future<void> killApp() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('killApp');
      }
    } catch (_) {}

    // Fallback exit Flutter & Dart OS
    try {
      await SystemNavigator.pop(animated: false);
    } catch (_) {}

    try {
      exit(0);
    } catch (_) {}
  }
}
