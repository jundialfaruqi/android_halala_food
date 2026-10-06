import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';
import '../utils/app_security_service.dart';
import 'app_button.dart';

/// Dialog peringatan keamanan yang tidak dapat ditutup (non-dismissible).
/// Ditampilkan saat terdeteksi Developer Mode atau Mock GPS.
/// Memiliki 1 tombol CTA "Oke, saya mengerti" yang langsung mematikan/kill aplikasi.
class AppSecurityDialog extends StatelessWidget {
  final SecurityCheckResult result;
  final VoidCallback onKillApp;

  const AppSecurityDialog({
    super.key,
    required this.result,
    required this.onKillApp,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Icon Peringatan Merah Solid
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    TablerIcons.shield_x,
                    color: AppColors.error,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                result.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandEspresso,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Pesan Instruksi
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.brandWarmGray,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),

              // 1 Tombol Call to Action: "Oke, saya mengerti" -> Kill Aplikasi
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Oke, saya mengerti',
                  height: 48,
                  borderRadius: 12,
                  backgroundColor: AppColors.error,
                  textColor: Colors.white,
                  icon: const Icon(
                    TablerIcons.power,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: onKillApp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
