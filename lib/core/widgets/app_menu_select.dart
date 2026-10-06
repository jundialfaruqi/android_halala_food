import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';

/// Item opsi untuk [AppMenuSelect] (Material 3 Menus).
class AppMenuSelectEntry<T> {
  final T value;
  final String label;
  final bool enabled;

  const AppMenuSelectEntry({
    required this.value,
    required this.label,
    this.enabled = true,
  });
}

/// Core widget form select menu berbasis komponen Material 3 Menus ([DropdownMenu]).
/// Disesuaikan dengan design system Halala Food:
/// - Menggunakan komponen Menus resmi Material 3 ([DropdownMenu] & [DropdownMenuEntry])
/// - Full-width sejajar dengan [AppTextField] menggunakan `expandedInsets: EdgeInsets.zero`
/// - Mencegah munculnya software keyboard pada layar sentuh (`requestFocusOnTap: false`)
/// - Terintegrasi dengan [FormField] untuk validasi form ([validator], error style)
class AppMenuSelect<T> extends FormField<T> {
  final String? labelText;
  final String? hintText;
  final List<AppMenuSelectEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final Widget? leadingIcon;

  AppMenuSelect({
    super.key,
    this.labelText,
    this.hintText,
    required this.entries,
    T? initialSelection,
    this.onSelected,
    super.enabled = true,
    this.leadingIcon,
    super.validator,
    super.autovalidateMode,
  }) : super(
          initialValue: initialSelection,
          builder: (FormFieldState<T> field) {
            final hasError = field.hasError;
            final effectiveErrorText = field.errorText;

            void handleSelected(T? value) {
              field.didChange(value);
              onSelected?.call(value);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (labelText != null) ...[
                  Text(
                    labelText,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                DropdownMenu<T>(
                  initialSelection: field.value,
                  enabled: field.widget.enabled,
                  requestFocusOnTap: false,
                  enableSearch: false,
                  expandedInsets: EdgeInsets.zero,
                  hintText: hintText ?? 'Pilih salah satu...',
                  leadingIcon: leadingIcon,
                  trailingIcon: const Icon(
                    TablerIcons.chevron_down,
                    size: 18,
                    color: AppColors.brandWarmGray,
                  ),
                  selectedTrailingIcon: const Icon(
                    TablerIcons.chevron_up,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    color: AppColors.brandEspresso,
                  ),
                  menuStyle: MenuStyle(
                    backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
                    surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
                    elevation: const WidgetStatePropertyAll<double>(6),
                    shape: WidgetStatePropertyAll<OutlinedBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.brandBorder),
                      ),
                    ),
                    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                      EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: hasError ? AppColors.error : AppColors.brandBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: hasError ? AppColors.error : AppColors.brandBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: hasError ? AppColors.error : AppColors.brandPrimary,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                  ),
                  dropdownMenuEntries: entries.map((entry) {
                    return DropdownMenuEntry<T>(
                      value: entry.value,
                      label: entry.label,
                      enabled: entry.enabled,
                      style: MenuItemButton.styleFrom(
                        foregroundColor: AppColors.brandEspresso,
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onSelected: handleSelected,
                ),
                if (hasError && effectiveErrorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    effectiveErrorText,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            );
          },
        );
}
