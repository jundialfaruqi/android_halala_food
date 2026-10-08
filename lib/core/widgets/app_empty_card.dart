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

  /// Ukuran icon jika tidak menggunakan [iconWidget]
  final double iconSize;

  /// Warna icon jika tidak menggunakan [iconWidget]
  final Color? iconColor;

  /// Judul pesan kosong
  final String title;

  /// Deskripsi atau penjelasan tambahan
  final String? message;

  /// Teks tombol aksi opsional (misal: 'Tambah Mitra Toko', 'Hapus Pencarian')
  final String? actionText;

  /// Icon untuk tombol aksi
  final IconData? actionIcon;

  /// Lebar tombol aksi opsional (null untuk menyesuaikan panjang teks otomatis)
  final double? actionWidth;

  /// Custom widget tombol aksi jika tidak menggunakan [actionText]
  final Widget? actionWidget;

  /// Varian tombol aksi (default: [AppButtonVariant.primary])
  final AppButtonVariant actionVariant;

  /// Callback saat tombol aksi ditekan
  final VoidCallback? onAction;

  /// Padding dalam card
  final EdgeInsetsGeometry padding;

  /// Margin luar card
  final EdgeInsetsGeometry? margin;

  /// Warna latar card
  final Color backgroundColor;

  /// Tampilkan border
  final bool hasBorder;

  /// Warna border (opsional, default: AppColors.brandBorder jika hasBorder true)
  final Color? borderColor;

  /// Tampilkan shadow lembut
  final bool hasShadow;

  /// Apakah dibungkus otomatis dengan [SingleChildScrollView] dan [Center]
  /// serta padding luar standar halaman pengantaran (EdgeInsets.symmetric(vertical: 40.0)).
  /// Default: true (otomatis konsisten di seluruh halaman tanpa perlu pembungkus manual).
  /// Atur ke false atau gunakan [AppEmptyCard.inline] jika ditaruh di dalam form/dialog inline.
  final bool isScrollable;

  /// Padding pembungkus luar jika [isScrollable] true.
  /// Default: [EdgeInsets.symmetric(vertical: 40.0)] (sesuai standar Halaman Pengantaran).
  final EdgeInsetsGeometry? outerPadding;

  const AppEmptyCard({
    super.key,
    this.icon = TablerIcons.inbox,
    this.iconWidget,
    this.iconSize = 54.0,
    this.iconColor,
    required this.title,
    this.message,
    this.actionText,
    this.actionIcon,
    this.actionWidth,
    this.actionWidget,
    this.actionVariant = AppButtonVariant.primary,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
    this.margin,
    this.backgroundColor = Colors.transparent,
    this.hasBorder = false,
    this.borderColor,
    this.hasShadow = false,
    this.isScrollable = true,
    this.outerPadding,
  });

  /// Factory / Constructor untuk penggunaan inline di dalam form atau dialog yang sudah memiliki scrollview sendiri.
  const AppEmptyCard.inline({
    super.key,
    this.icon = TablerIcons.inbox,
    this.iconWidget,
    this.iconSize = 54.0,
    this.iconColor,
    required this.title,
    this.message,
    this.actionText,
    this.actionIcon,
    this.actionWidth,
    this.actionWidget,
    this.actionVariant = AppButtonVariant.primary,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
    this.margin,
    this.backgroundColor = Colors.transparent,
    this.hasBorder = false,
    this.borderColor,
    this.hasShadow = false,
    this.outerPadding,
  }) : isScrollable = false;

  /// Factory untuk kondisi pencarian tidak menemukan hasil
  factory AppEmptyCard.search({
    Key? key,
    IconData icon = TablerIcons.search_off,
    String? query,
    VoidCallback? onReset,
    String? message,
    Color backgroundColor = Colors.transparent,
    bool hasBorder = false,
    Color? borderColor,
    bool hasShadow = false,
    double iconSize = 54.0,
    Color? iconColor,
    double? actionWidth,
    bool isScrollable = true,
    EdgeInsetsGeometry? outerPadding,
  }) {
    return AppEmptyCard(
      key: key,
      icon: icon,
      iconSize: iconSize,
      iconColor: iconColor,
      title: 'Tidak Ada Hasil Ditemukan',
      message: message ??
          (query != null && query.isNotEmpty
              ? 'Tidak ditemukan data yang cocok dengan kata kunci "$query".'
              : 'Tidak ada data yang sesuai dengan kriteria pencarian Anda.'),
      actionText: onReset != null ? 'Hapus Pencarian' : null,
      actionIcon: TablerIcons.x,
      actionWidth: actionWidth,
      onAction: onReset,
      backgroundColor: backgroundColor,
      hasBorder: hasBorder,
      borderColor: borderColor,
      hasShadow: hasShadow,
      isScrollable: isScrollable,
      outerPadding: outerPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      borderColor: borderColor ?? (hasBorder ? AppColors.brandBorder : Colors.transparent),
      borderWidth: (hasBorder || borderColor != null) ? 1.0 : 0.0,
      boxShadow: hasShadow ? null : const [],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Only dengan warna memudar lembut
            iconWidget ??
                Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? AppColors.brandWarmGray.withValues(alpha: 0.55),
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

            // Tombol Aksi Opsional (Call to Action)
            if (actionWidget != null) ...[
              const SizedBox(height: 20),
              actionWidget!,
            ] else if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                text: actionText!,
                icon: actionIcon != null
                    ? Icon(actionIcon, size: 18)
                    : null,
                width: actionWidth,
                height: 44,
                variant: actionVariant,
                borderRadius: 12,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );

    if (!isScrollable) {
      if (outerPadding != null && outerPadding != EdgeInsets.zero) {
        return Padding(
          padding: outerPadding!,
          child: card,
        );
      }
      return card;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: outerPadding ?? const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: card,
      ),
    );
  }
}
