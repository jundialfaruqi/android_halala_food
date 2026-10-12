import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

/// Reusable core component filter date picker berbentuk container yang seragam dengan [AppFilterDropdown].
/// 
/// Fitur:
/// - Nilai default [selectedDate] adalah `null` dengan placeholder [placeholder] (default: `'Pilih Tanggal'`).
/// - Ketika bernilai `null`, border netral dan data tidak difilter.
/// - Ketika tanggal dipilih, border dan teks menggunakan warna [AppColors.brandPrimary].
/// - Mendukung tombol clear (silang `x`) saat tanggal terpilih untuk mereset filter kembali ke `null`.
/// - Dialog pemilih tanggal mengikuti tema warna Halala Food.
class AppFilterDatePicker extends StatelessWidget {
  /// Nilai tanggal yang saat ini dipilih. `null` berarti belum difilter / semua data.
  final DateTime? selectedDate;

  /// Callback ketika tanggal dipilih atau direset (`null`).
  final ValueChanged<DateTime?> onDateSelected;

  /// Teks placeholder saat [selectedDate] bernilai `null` (default: `'Pilih Tanggal'`).
  final String placeholder;

  /// Prefix teks yang ditampilkan saat tanggal dipilih (opsional).
  final String? prefixLabel;

  /// Tooltip saat tombol di-hover atau long-press (default: `'Filter Tanggal'`).
  final String? tooltip;

  /// Tinggi widget (default: `46.0` agar sejajar dengan filter dropdown).
  final double height;

  /// Padding dalam kontainer trigger.
  final EdgeInsetsGeometry? padding;

  /// Border radius kustom kontainer trigger (default: `10.0`).
  final BorderRadiusGeometry? borderRadius;

  /// Batas tanggal awal pemilihan (default: `2020-01-01`).
  final DateTime? firstDate;

  /// Batas tanggal akhir pemilihan (default: `2035-12-31`).
  final DateTime? lastDate;

  /// Formatter kustom untuk tanggal yang dipilih.
  /// Default: `DateFormat('d MMM yyyy', 'id_ID')` (misal: '13 Okt 2026').
  final String Function(DateTime date)? dateFormatter;

  /// Menampilkan tombol silang `x` untuk mereset tanggal kembali ke `null` saat terpilih.
  final bool allowClear;

  /// Menampilkan soft shadow pada tombol trigger (default: `false`).
  final bool showShadow;

  /// Ukuran font teks trigger (default: `13`).
  final double fontSize;

  const AppFilterDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.placeholder = 'Pilih Tanggal',
    this.prefixLabel,
    this.tooltip = 'Filter Tanggal',
    this.height = 46.0,
    this.padding,
    this.borderRadius,
    this.firstDate,
    this.lastDate,
    this.dateFormatter,
    this.allowClear = true,
    this.showShadow = false,
    this.fontSize = 13,
  });

  String _formatDate(DateTime date) {
    if (dateFormatter != null) {
      return dateFormatter!(date);
    }
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  String _getDisplayText() {
    if (selectedDate == null) return placeholder;
    final formatted = _formatDate(selectedDate!);
    if (prefixLabel != null && prefixLabel!.isNotEmpty) {
      return '$prefixLabel$formatted';
    }
    return formatted;
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final effectiveFirst = firstDate ?? DateTime(2020);
    final effectiveLast = lastDate ?? DateTime(2035);

    DateTime initialDate = selectedDate ?? now;
    if (initialDate.isBefore(effectiveFirst)) {
      initialDate = effectiveFirst;
    } else if (initialDate.isAfter(effectiveLast)) {
      initialDate = effectiveLast;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      helpText: placeholder,
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.brandEspresso,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedDate != null;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(10.0);
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 12);

    final effectiveBorderColor =
        isSelected ? AppColors.brandPrimary : AppColors.brandBorder;
    final effectiveBorderWidth = isSelected ? 1.2 : 1.0;

    final triggerTextColor =
        isSelected ? AppColors.brandPrimary : AppColors.brandWarmGray;
    final triggerFontWeight =
        isSelected ? FontWeight.w700 : FontWeight.w500;

    return Tooltip(
      message: tooltip ?? placeholder,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _pickDate(context),
          borderRadius: effectiveRadius as BorderRadius?,
          child: Container(
            height: height,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _getDisplayText(),
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
                if (isSelected && allowClear)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDateSelected(null),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        TablerIcons.x,
                        size: 16,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  )
                else
                  Icon(
                    TablerIcons.calendar,
                    size: 16,
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.brandWarmGray,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
