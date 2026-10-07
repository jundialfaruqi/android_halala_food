import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';

/// Reusable core component filter dropdown berbentuk pill/capsule atau expanded container.
/// Menggunakan [PopupMenuButton] dengan styling khas Halala Food:
/// - Rounded border dengan border aktif [AppColors.brandPrimary]
/// - Pilihan "Semua" di posisi teratas dengan [PopupMenuDivider]
/// - Opsi aktif ditandai dengan font tebal dan warna brand
/// - Mendukung mode pill (compact/minAxisSize) atau expanded (full width form/filter bar)
class AppFilterDropdown<T> extends StatelessWidget {
  /// Nilai item yang saat ini dipilih. `null` berarti opsi "Semua" (unfiltered).
  final T? selectedValue;

  /// Daftar item pilihan yang tersedia.
  final List<T> items;

  /// Callback ketika salah satu opsi dipilih.
  /// Mengembalikan `null` jika pengguna memilih opsi "Semua".
  final ValueChanged<T?> onSelected;

  /// Label teks untuk opsi "Semua" (default: `'Semua Rute'`).
  final String allLabel;

  /// Fungsi pengubah objek item menjadi teks String (default: `item.toString()`).
  final String Function(T item)? itemLabel;

  /// Prefix teks yang ditampilkan pada trigger saat ada item terpilih (contoh: `'Rute: '`).
  final String? prefixLabel;

  /// Formatter kustom untuk teks label trigger ketika nilai terpilih.
  final String Function(T item)? selectedLabelBuilder;

  /// Tooltip saat tombol di-hover atau long-press (default: `'Filter'`).
  final String? tooltip;

  /// Jika true, lebar widget menyesuaikan parent ([double.infinity]) dan teks otomatis ellipsis.
  final bool isExpanded;

  /// Tinggi widget (secara default `42` jika [isExpanded], atau wrap content jika false).
  final double? height;

  /// Padding dalam kontainer trigger.
  final EdgeInsetsGeometry? padding;

  /// Border radius kustom kontainer trigger.
  final BorderRadiusGeometry? borderRadius;

  /// Offset posisi menu pop-up relatif terhadap tombol trigger.
  final Offset? offset;

  /// Batasan ukuran menu pop-up (constraints).
  final BoxConstraints? menuConstraints;

  /// Ketinggian elevasi bayangan pop-up menu (default: `6`).
  final double elevation;

  /// Menampilkan soft shadow pada tombol trigger (default: `true`).
  final bool showShadow;

  /// Ikon chevron (default: [TablerIcons.chevron_down]).
  final IconData icon;

  /// Ukuran ikon chevron.
  final double? iconSize;

  /// Ukuran font teks trigger (default: `13`).
  final double fontSize;

  const AppFilterDropdown({
    super.key,
    required this.selectedValue,
    required this.items,
    required this.onSelected,
    this.allLabel = 'Semua Rute',
    this.itemLabel,
    this.prefixLabel,
    this.selectedLabelBuilder,
    this.tooltip = 'Filter',
    this.isExpanded = false,
    this.height,
    this.padding,
    this.borderRadius,
    this.offset,
    this.menuConstraints,
    this.elevation = 6,
    this.showShadow = true,
    this.icon = TablerIcons.chevron_down,
    this.iconSize,
    this.fontSize = 13,
  });

  String _formatItem(T item) {
    if (itemLabel != null) return itemLabel!(item);
    return item.toString();
  }

  String _getTriggerText() {
    if (selectedValue == null) return allLabel;
    if (selectedLabelBuilder != null) {
      return selectedLabelBuilder!(selectedValue as T);
    }
    final formatted = _formatItem(selectedValue as T);
    if (prefixLabel != null && prefixLabel!.isNotEmpty) {
      return '$prefixLabel$formatted';
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final isFiltered = selectedValue != null;
    final effectiveHeight = height ?? (isExpanded ? 42.0 : null);
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(isExpanded ? 10.0 : 20.0);
    final effectivePadding = padding ??
        (isExpanded
            ? const EdgeInsets.symmetric(horizontal: 12)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 7));
    final effectiveOffset =
        offset ?? (isExpanded ? const Offset(0, 44) : const Offset(0, 38));
    final effectiveIconSize = iconSize ?? (isExpanded ? 16.0 : 14.0);

    return PopupMenuButton<T?>(
      tooltip: tooltip,
      offset: effectiveOffset,
      elevation: elevation,
      color: Colors.white,
      constraints: menuConstraints ??
          BoxConstraints(minWidth: isExpanded ? 200 : 150),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          // Opsi Semua / Tanpa Filter
          PopupMenuItem<T?>(
            value: null,
            height: 40,
            child: Text(
              allLabel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: !isFiltered ? FontWeight.w700 : FontWeight.w500,
                color: !isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),
          // Opsi masing-masing item
          ...items.map(
            (item) {
              final isItemActive = selectedValue == item;
              return PopupMenuItem<T?>(
                value: item,
                height: 40,
                child: Text(
                  _formatItem(item),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: isItemActive ? FontWeight.w700 : FontWeight.w500,
                    color: isItemActive
                        ? AppColors.brandPrimary
                        : AppColors.brandEspresso,
                  ),
                ),
              );
            },
          ),
        ];
      },
      child: Container(
        height: effectiveHeight,
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: effectiveRadius,
          border: Border.all(
            color: isFiltered ? AppColors.brandPrimary : AppColors.brandBorder,
            width: isFiltered ? 1.2 : 1.0,
          ),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isExpanded
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getTriggerText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: fontSize,
                        fontWeight:
                            isFiltered ? FontWeight.w700 : FontWeight.w600,
                        color: isFiltered
                            ? AppColors.brandPrimary
                            : AppColors.brandEspresso,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    icon,
                    size: effectiveIconSize,
                    color: isFiltered
                        ? AppColors.brandPrimary
                        : AppColors.brandWarmGray,
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTriggerText(),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: fontSize,
                      fontWeight:
                          isFiltered ? FontWeight.w700 : FontWeight.w600,
                      color: isFiltered
                          ? AppColors.brandPrimary
                          : AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    icon,
                    size: effectiveIconSize,
                    color: isFiltered
                        ? AppColors.brandPrimary
                        : AppColors.brandWarmGray,
                  ),
                ],
              ),
      ),
    );
  }
}
