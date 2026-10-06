import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_security_service.dart';
import 'app_security_dialog.dart';

/// Wrapper global untuk mendeteksi Developer Mode dan Mock GPS secara pintar dan real-time.
/// Hanya aktif di Release Mode (`kReleaseMode == true`).
///
/// Jika pengguna mengaktifkan mode pengembang di tengah-tengah penggunaan aplikasi
/// (misal membuka Settings lalu kembali ke aplikasi atau via split-screen / quick settings),
/// dialog peringatan akan langsung muncul menutupi seluruh layar dan menolak interaksi apapun
/// hingga tombol "Oke, saya mengerti" ditekan untuk menutup/kill aplikasi.
class AppSecurityWrapper extends StatefulWidget {
  final Widget child;

  const AppSecurityWrapper({super.key, required this.child});

  @override
  State<AppSecurityWrapper> createState() => _AppSecurityWrapperState();
}

class _AppSecurityWrapperState extends State<AppSecurityWrapper>
    with WidgetsBindingObserver {
  Timer? _periodicTimer;
  SecurityCheckResult? _currentViolation;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Dengarkan perubahan status pelanggaran dari service
    AppSecurityService.violationNotifier.addListener(_onViolationChanged);
    _currentViolation = AppSecurityService.violationNotifier.value;

    if (AppSecurityService.isProtectionActive) {
      // 1. Pengecekan saat awal aplikasi dibuka
      _runSecurityCheck();

      // 2. Timer periodik cerdas (setiap 2 detik) untuk mendeteksi user
      // yang mengaktifkan dev mode / fake GPS saat aplikasi sedang berjalan
      _periodicTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_currentViolation == null && mounted) {
          _runSecurityCheck();
        }
      });
    }
  }

  void _onViolationChanged() {
    if (!mounted) return;
    setState(() {
      _currentViolation = AppSecurityService.violationNotifier.value;
    });
  }

  Future<void> _runSecurityCheck() async {
    if (_isChecking || !AppSecurityService.isProtectionActive) return;
    _isChecking = true;

    try {
      final result = await AppSecurityService.checkSecurity();
      if (mounted && result.isCompromised) {
        setState(() {
          _currentViolation = result;
        });
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saat user kembali dari Settings atau aplikasi lain ke Halala Food
    if (state == AppLifecycleState.resumed) {
      _runSecurityCheck();
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSecurityService.violationNotifier.removeListener(_onViolationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final violation = _currentViolation;

    if (violation == null || !violation.isCompromised) {
      return widget.child;
    }

    return PopScope(
      canPop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Konten aplikasi di latar belakang diblokir sepenuhnya
          widget.child,

          // Lapisan Modal Barrier gelap permanen yang menyerap semua sentuhan
          const ModalBarrier(
            dismissible: false,
            color: Color(0x99000000), // Black 60%
          ),

          // Dialog Keamanan Terpusat
          AppSecurityDialog(
            result: violation,
            onKillApp: () => AppSecurityService.killApp(),
          ),
        ],
      ),
    );
  }
}
