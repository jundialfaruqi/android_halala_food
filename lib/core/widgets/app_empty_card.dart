import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Widget Core Empty Card untuk menampilkan keadaan kosong (empty state),
/// tidak ada data, atau hasil pencarian tidak ditemukan.
class AppEmptyCard extends StatelessWidget {
  /// Icon utama yang ditampilkan
  final IconData icon;

  /// Custom widget icon/ilustrasi jika tidak menggunakan [icon]
  final Widget? iconWidget;

  /// Judul pesan kosong
  final String title;

  /// Deskripsi atau penjelasan tambahan
  final String? message;

  /// Teks tombol aksi opsional (misal: 'Reset Pencarian', 'Muat Ulang')
  final String? actionText;

  /// Icon untuk tombol aksi
  final IconData? actionIcon;

  /// Callback saat tombol aksi ditekan
  final VoidCallback? onAction;

  /// Padding dalam card
  final EdgeInsetsGeometry padding;

  /// Margin luar card
  final EdgeInsetsGeometry? margin;

  /// Warna latar card
  final Color backgroundColor;

  /// Tampilkan shadow lembut
  final bool hasShadow;

  const AppEmptyCard({
    super.key,
    this.icon = TablerIcons.inbox,
    this.iconWidget,
    required this.title,
    this.message,
    this.actionText,
    this.actionIcon,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
    this.margin,
    this.backgroundColor = Colors.white,
    this.hasShadow = true,
  });

  /// Factory untuk kondisi pencarian tidak menemukan hasil
  factory AppEmptyCard.search({
    Key? key,
    String? query,
    VoidCallback? onReset,
    String? message,
  }) {
    return AppEmptyCard(
      key: key,
      icon: TablerIcons.search_off,
      title: 'Tidak Ada Hasil Ditemukan',
      message: message ??
          (query != null && query.isNotEmpty
              ? 'Tidak ditemukan data yang cocok dengan kata kunci "$query".'
              : 'Tidak ada data yang sesuai dengan kriteria pencarian Anda.'),
      actionText: onReset != null ? 'Hapus Pencarian' : null,
      actionIcon: TablerIcons.x,
      onAction: onReset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      boxShadow: hasShadow ? null : const [],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Container Icon Berbulat Lembut
            iconWidget ??
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCream,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brandBorder,
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 28,
                    color: AppColors.brandPrimary,
                  ),
                ),
            const SizedBox(height: 16),

            // Judul
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.brandEspresso,
              ),
            ),

            // Deskripsi / Pesan
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],

            // Tombol Aksi Opsional
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                text: actionText!,
                icon: actionIcon != null
                    ? Icon(actionIcon, size: 16)
                    : null,
                width: 170,
                height: 42,
                variant: AppButtonVariant.primary,
                borderRadius: 10,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
