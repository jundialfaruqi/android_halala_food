import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';
import 'app_text_field.dart';

/// Widget Core Form Input Pencarian Halala Food.
/// Menggunakan basis standar AppTextField dengan icon search dan tombol clear otomatis.
/// Digunakan secara konsisten di seluruh halaman yang memiliki fitur pencarian (Mitra Toko, Produk, dll).
class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Cari...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.enabled = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget field;

    if (controller != null) {
      field = ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller!,
        builder: (context, value, _) {
          return AppTextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            hintText: hintText,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            prefixIcon: const Icon(
              TablerIcons.search,
              size: 20,
              color: AppColors.brandWarmGray,
            ),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(TablerIcons.x, size: 18),
                    color: AppColors.brandWarmGray,
                    tooltip: 'Hapus Pencarian',
                    onPressed: () {
                      controller!.clear();
                      if (onClear != null) {
                        onClear!();
                      } else if (onChanged != null) {
                        onChanged!('');
                      }
                    },
                  )
                : null,
          );
        },
      );
    } else {
      field = AppTextField(
        focusNode: focusNode,
        enabled: enabled,
        hintText: hintText,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        prefixIcon: const Icon(
          TablerIcons.search,
          size: 20,
          color: AppColors.brandWarmGray,
        ),
      );
    }

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: field,
      );
    }

    return field;
  }
}
