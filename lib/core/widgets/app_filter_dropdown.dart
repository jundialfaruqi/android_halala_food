import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';

const Object _kFilterAllSentinel = Object();

/// Reusable core component filter dropdown berbentuk pill/capsule atau expanded container.
/// Menggunakan [PopupMenuButton] dengan styling khas Halala Food:
/// - Rounded border dengan border aktif [AppColors.brandPrimary] (atau border netral pada mode formulir)
/// - Pilihan "Semua" di posisi teratas dengan [PopupMenuDivider] jika [showAllOption] bernilai `true`
/// - Opsi aktif ditandai dengan font tebal dan warna brand
/// - Mendukung mode pill (compact/minAxisSize) atau expanded (full width form/filter bar)
/// - Mendukung mode formulir (tanpa opsi "Semua", dengan placeholder/hint text, dan validasi error border)
class AppFilterDropdown<T> extends StatelessWidget {
  /// Nilai item yang saat ini dipilih. `null` berarti opsi "Semua" (unfiltered) atau belum dipilih.
  final T? selectedValue;

  /// Daftar item pilihan yang tersedia.
  final List<T> items;

  /// Callback ketika salah satu opsi dipilih.
  /// Mengembalikan `null` jika pengguna memilih opsi "Semua".
  final ValueChanged<T?> onSelected;

  /// Label teks untuk opsi "Semua" atau placeholder saat belum ada item dipilih (default: `'Semua Rute'`).
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

  /// Tinggi widget (secara default `46` jika [isExpanded], atau wrap content jika false).
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

  /// Jika false, opsi "Semua" tidak ditampilkan pada menu pop-up (cocok untuk formulir input yang wajib memilih salah satu nilai).
  final bool showAllOption;

  /// Menandakan field dalam kondisi error validasi (border dan teks merah).
  final bool hasError;

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
    this.showAllOption = true,
    this.hasError = false,
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
    final isSelected = selectedValue != null;
    final isFormMode = !showAllOption;
    final effectiveHeight = height ?? (isExpanded ? 46.0 : null);
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(isExpanded ? 10.0 : 20.0);
    final effectivePadding = padding ??
        (isExpanded
            ? const EdgeInsets.symmetric(horizontal: 14)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 7));
    final effectiveOffset =
        offset ?? (isExpanded ? const Offset(0, 48) : const Offset(0, 38));
    final effectiveIconSize = iconSize ?? (isExpanded ? 16.0 : 14.0);

    // Penentuan warna border:
    Color effectiveBorderColor;
    if (hasError) {
      effectiveBorderColor = const Color(0xFFDC2626);
    } else if (isFormMode) {
      effectiveBorderColor = AppColors.brandBorder;
    } else {
      effectiveBorderColor =
          isSelected ? AppColors.brandPrimary : AppColors.brandBorder;
    }

    final effectiveBorderWidth =
        (hasError || (!isFormMode && isSelected)) ? 1.2 : 1.0;

    // Penentuan styling teks trigger:
    Color triggerTextColor;
    FontWeight triggerFontWeight;
    if (isFormMode) {
      if (!isSelected) {
        triggerTextColor =
            hasError ? const Color(0xFFDC2626) : AppColors.brandWarmGray;
        triggerFontWeight = FontWeight.w500;
      } else {
        triggerTextColor = AppColors.brandEspresso;
        triggerFontWeight = FontWeight.w600;
      }
    } else {
      if (isSelected) {
        triggerTextColor = AppColors.brandPrimary;
        triggerFontWeight = FontWeight.w700;
      } else {
        triggerTextColor = AppColors.brandEspresso;
        triggerFontWeight = FontWeight.w600;
      }
    }

    // Penentuan warna ikon:
    Color triggerIconColor;
    if (hasError) {
      triggerIconColor = const Color(0xFFDC2626);
    } else if (isFormMode) {
      triggerIconColor =
          isSelected ? AppColors.brandEspresso : AppColors.brandWarmGray;
    } else {
      triggerIconColor =
          isSelected ? AppColors.brandPrimary : AppColors.brandWarmGray;
    }

    return PopupMenuButton<Object?>(
      tooltip: tooltip,
      offset: effectiveOffset,
      elevation: elevation,
      color: Colors.white,
      constraints: menuConstraints ??
          BoxConstraints(minWidth: isExpanded ? 240 : 150, maxHeight: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      onSelected: (val) {
        if (val == _kFilterAllSentinel) {
          onSelected(null);
        } else if (val is T) {
          onSelected(val);
        }
      },
      itemBuilder: (context) {
        final menuItems = <PopupMenuEntry<Object?>>[];

        if (showAllOption) {
          menuItems.add(
            PopupMenuItem<Object?>(
              value: _kFilterAllSentinel,
              height: 40,
              child: Text(
                allLabel,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: !isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: !isSelected
                      ? AppColors.brandPrimary
                      : AppColors.brandEspresso,
                ),
              ),
            ),
          );
          menuItems.add(const PopupMenuDivider(height: 1));
        }

        menuItems.addAll(
          items.map(
            (item) {
              final isItemActive = selectedValue == item;
              return PopupMenuItem<Object?>(
                value: item,
                height: 40,
                child: Text(
                  _formatItem(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight:
                        isItemActive ? FontWeight.w700 : FontWeight.w500,
                    color: isItemActive
                        ? AppColors.brandPrimary
                        : AppColors.brandEspresso,
                  ),
                ),
              );
            },
          ),
        );

        return menuItems;
      },
      child: Container(
        height: effectiveHeight,
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: effectiveRadius,
          border: Border.all(
            color: effectiveBorderColor,
            width: effectiveBorderWidth,
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
                        fontWeight: triggerFontWeight,
                        color: triggerTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    icon,
                    size: effectiveIconSize,
                    color: triggerIconColor,
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
                      fontWeight: triggerFontWeight,
                      color: triggerTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    icon,
                    size: effectiveIconSize,
                    color: triggerIconColor,
                  ),
                ],
              ),
      ),
    );
  }
}
