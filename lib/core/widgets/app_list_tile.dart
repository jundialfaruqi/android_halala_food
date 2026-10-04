import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';

/// Widget List Tile inti (core) Halala Food untuk item navigasi, pengaturan, dan data item.
class AppListTile extends StatelessWidget {
  /// Widget di sisi kiri (avatar, custom icon, image)
  final Widget? leading;

  /// Icon praktis untuk sisi kiri (jika tidak menggunakan [leading] kustom)
  final IconData? leadingIcon;

  /// Warna icon pada [leadingIcon]
  final Color leadingIconColor;

  /// Warna latar bulatan [leadingIcon]
  final Color leadingIconBackgroundColor;

  /// Judul utama tile
  final String title;

  /// Sub-judul / teks sekunder di bawah judul
  final String? subtitle;

  /// Widget di sisi kanan (switch, counter, button, text)
  final Widget? trailing;

  /// Teks ringkas di sisi kanan (sebelum chevron jika ada)
  final String? trailingText;

  /// Tampilkan icon panah kanan (chevron) otomatis
  final bool showChevron;

  /// Label badge kecil di samping judul
  final String? badge;

  /// Warna latar badge
  final Color badgeColor;

  /// Warna teks badge
  final Color badgeTextColor;

  /// Mode aksi berbahaya (merah / destructive)
  final bool isDestructive;

  /// Tambahkan garis divider pemisah di bagian bawah tile
  final bool isDividerAfter;

  /// Padding dalam tile
  final EdgeInsetsGeometry padding;

  /// Aksi ketika tile ditekan
  final VoidCallback? onTap;

  /// Aksi ketika tile ditekan lama
  final VoidCallback? onLongPress;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingIconColor = AppColors.brandPrimary,
    this.leadingIconBackgroundColor = AppColors.brandSoftCream,
    this.trailing,
    this.trailingText,
    this.showChevron = false,
    this.badge,
    this.badgeColor = AppColors.brandSoftCream,
    this.badgeTextColor = AppColors.brandPrimary,
    this.isDestructive = false,
    this.isDividerAfter = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive ? AppColors.error : AppColors.brandEspresso;
    final iconColor = isDestructive ? AppColors.error : leadingIconColor;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      leadingWidget = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.1)
              : leadingIconBackgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          leadingIcon,
          size: 19,
          color: iconColor,
        ),
      );
    }

    Widget content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.brandWarmGray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: 8),
            Text(
              trailingText!,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.brandWarmGray,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: 6),
            const Icon(
              TablerIcons.chevron_right,
              size: 18,
              color: AppColors.brandWarmGray,
            ),
          ],
        ],
      ),
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }

    if (isDividerAfter) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.brandBorder,
          ),
        ],
      );
    }

    return content;
  }
}

/// Widget Group Section untuk mengelompokkan beberapa [AppListTile] dalam satu Card atau Grup List.
class AppListSection extends StatelessWidget {
  /// Judul section (misal: "PENGATURAN AKUN", "DATA MASTER")
  final String? title;

  /// Aksi di sisi kanan header section (misal: "Lihat Semua")
  final Widget? action;

  /// Daftar item tile di dalam section
  final List<Widget> children;

  /// Bungkus seluruh item ke dalam [AppCard] berbingkai halus
  final bool cardWrapper;

  /// Berikan divider otomatis di antara setiap item tile
  final bool separated;

  /// Margin luar section
  final EdgeInsetsGeometry? margin;

  const AppListSection({
    super.key,
    this.title,
    this.action,
    required this.children,
    this.cardWrapper = true,
    this.separated = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final List<Widget> listItems = [];
    for (int i = 0; i < children.length; i++) {
      listItems.add(children[i]);
      if (separated && i < children.length - 1) {
        listItems.add(
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.brandBorder,
          ),
        );
      }
    }

    Widget content;
    if (cardWrapper) {
      content = AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: listItems,
        ),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: listItems,
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || action != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.brandWarmGray,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (action != null) action!,
                ],
              ),
            ),
          ],
          content,
        ],
      ),
    );
  }
}
