import 'package:flutter/services.dart';

/// Formatter untuk input nomor HP Indonesia dengan prefix +62
/// Secara otomatis menghilangkan awalan '0' atau '62' saat user mengetik atau menempelkan (paste) teks
class IndonesianPhoneInputFormatter extends TextInputFormatter {
  const IndonesianPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 1. Ekstrak hanya digit angka
    String formatted = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Hilangkan prefix 62 jika ada (misal copy-paste +628... atau 628...)
    if (formatted.startsWith('62')) {
      formatted = formatted.substring(2);
    }

    // 3. Hilangkan angka 0 di depan (misal user mengetik 0821...)
    while (formatted.startsWith('0')) {
      formatted = formatted.substring(1);
    }

    // 4. Batasi panjang nomor HP wajar di Indonesia (maksimal 13 digit setelah +62)
    if (formatted.length > 13) {
      formatted = formatted.substring(0, 13);
    }

    // 5. Hitung posisi kursor secara presisi
    final selectionIndex = newValue.selection.baseOffset;
    final diff = newValue.text.length - formatted.length;
    final newOffset = (selectionIndex - diff).clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
