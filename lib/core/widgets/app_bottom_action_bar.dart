import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

/// Core widget bar aksi bawah (Bottom Action Bar) untuk formulir Halala Food.
/// Digunakan pada properti `bottomNavigationBar` di `AppScaffold`
/// pada seluruh halaman form Tambah & Edit (Mitra Toko, Produk Jadi, Pengguna).
class AppBottomActionBar extends StatelessWidget {
  /// Teks tombol utama / konfirmasi (contoh: 'Simpan', 'Tambah Pengguna')
  final String confirmText;

  /// Callback ketika tombol konfirmasi ditekan
  final VoidCallback? onConfirm;

  /// Teks tombol batal / sekunder (default: 'Batal')
  final String cancelText;

  /// Callback ketika tombol batal ditekan (default: Navigator.of(context).pop())
  final VoidCallback? onCancel;

  /// Status loading tombol utama
  final bool isLoading;

  /// Menampilkan tombol batal atau tidak (default: true)
  final bool showCancel;

  /// Rasio lebar tombol batal (default: 1)
  final int cancelFlex;

  /// Rasio lebar tombol konfirmasi (default: 2)
  final int confirmFlex;

  /// Jarak spasi antar tombol (default: 12.0)
  final double spacing;

  /// Warna border tombol batal (default: ghost border grey #D1D5DB)
  final Color? cancelBorderColor;

  /// Icon opsional untuk tombol konfirmasi
  final Widget? confirmIcon;

  /// Custom child jika dibutuhkan layout tombol kustom di dalam bar
  final Widget? customChild;

  const AppBottomActionBar({
    super.key,
    this.confirmText = 'Simpan',
    this.onConfirm,
    this.cancelText = 'Batal',
    this.onCancel,
    this.isLoading = false,
    this.showCancel = true,
    this.cancelFlex = 1,
    this.confirmFlex = 2,
    this.spacing = 12.0,
    this.cancelBorderColor = const Color(0xFFD1D5DB),
    this.confirmIcon,
    this.customChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.brandBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: customChild ??
            Row(
              children: [
                if (showCancel) ...[
                  Expanded(
                    flex: cancelFlex,
                    child: AppButton.outline(
                      text: cancelText,
                      borderColor: cancelBorderColor,
                      onPressed: isLoading
                          ? null
                          : (onCancel ?? () => Navigator.of(context).pop()),
                    ),
                  ),
                  SizedBox(width: spacing),
                ],
                Expanded(
                  flex: confirmFlex,
                  child: AppButton(
                    text: confirmText,
                    icon: confirmIcon,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : onConfirm,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
