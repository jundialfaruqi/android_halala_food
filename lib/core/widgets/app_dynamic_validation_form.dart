import 'package:flutter/material.dart';

/// Core Widget Form dengan Dynamic Validation Clearing otomatis.
///
/// Menyediakan manajemen status validasi form yang cerdas dan modern:
/// 1. Saat form pertama kali dibuka, mode validasi default adalah [AutovalidateMode.disabled]
///    sehingga pengguna tidak langsung dibanjiri pesan error sebelum menekan tombol simpan.
/// 2. Ketika metode [validate] dipanggil dan form tidak valid, form secara otomatis
///    beralih ke mode [AutovalidateMode.onUserInteraction].
/// 3. Begitu mode aktif, setiap kali pengguna mulai mengetik atau mengubah input pada
///    kolom form yang error, pesan validasi error akan langsung BERSIH (cleared) secara dinamis
///    tanpa perlu menekan tombol submit ulang.
/// 4. Menyediakan method [reset] dan [clearValidation] untuk mengembalikan status validasi.
class AppDynamicValidationForm extends StatefulWidget {
  final Widget child;
  final GlobalKey<FormState>? innerFormKey;
  final VoidCallback? onChanged;
  final AutovalidateMode? initialAutovalidateMode;

  const AppDynamicValidationForm({
    super.key,
    this.innerFormKey,
    required this.child,
    this.onChanged,
    this.initialAutovalidateMode,
  });

  /// Helper untuk mengakses state [AppDynamicValidationFormState] terdekat
  static AppDynamicValidationFormState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppDynamicValidationFormState>();
  }

  @override
  State<AppDynamicValidationForm> createState() =>
      AppDynamicValidationFormState();
}

class AppDynamicValidationFormState extends State<AppDynamicValidationForm> {
  late final GlobalKey<FormState> _effectiveFormKey;
  late AutovalidateMode _autovalidateMode;

  GlobalKey<FormState> get formKey => _effectiveFormKey;
  AutovalidateMode get autovalidateMode => _autovalidateMode;

  @override
  void initState() {
    super.initState();
    _effectiveFormKey = widget.innerFormKey ?? GlobalKey<FormState>();
    _autovalidateMode =
        widget.initialAutovalidateMode ?? AutovalidateMode.disabled;
  }

  /// Memvalidasi seluruh FormField di dalam form.
  /// Jika terdapat input yang tidak valid, otomatis beralih ke
  /// [AutovalidateMode.onUserInteraction] untuk mengaktifkan Dynamic Validation Clearing.
  bool validate() {
    final isValid = _effectiveFormKey.currentState?.validate() ?? false;
    if (!isValid && _autovalidateMode != AutovalidateMode.onUserInteraction) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }
    return isValid;
  }

  /// Simpan semua nilai FormField
  void save() {
    _effectiveFormKey.currentState?.save();
  }

  /// Reset semua kolom form dan kembalikan mode validasi ke disabled
  void reset() {
    _effectiveFormKey.currentState?.reset();
    setState(() {
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  /// Membersihkan status autovalidate (kembali ke disabled)
  void clearValidation() {
    if (_autovalidateMode != AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.disabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _effectiveFormKey,
      autovalidateMode: _autovalidateMode,
      onChanged: widget.onChanged,
      child: widget.child,
    );
  }
}
