import 'package:flutter/services.dart';

/// Formatter untuk input angka nominal/harga dengan pemisah titik ribuan (standar Indonesia)
/// Contoh: 18000 -> 18.000, 1500000 -> 1.500.000
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const ThousandsSeparatorInputFormatter({this.maxDigits = 12});

  /// Format angka [num] menjadi string bertitik ribuan
  /// Contoh: format(18000) -> "18.000"
  static String format(num value) {
    return formatString(value.toInt().toString());
  }

  /// Format deretan digit string menjadi string bertitik ribuan
  /// Contoh: formatString("18000") -> "18.000"
  static String formatString(String digitsOnly) {
    if (digitsOnly.isEmpty) return '';

    String clean = digitsOnly.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return '';

    // Hapus leading zero berlebih (kecuali angka 0 itu sendiri)
    while (clean.length > 1 && clean.startsWith('0')) {
      clean = clean.substring(1);
    }

    final StringBuffer buffer = StringBuffer();
    final int length = clean.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  /// Parse teks dengan pemisah titik menjadi double murni
  /// Contoh: parseToDouble("18.000") -> 18000.0
  static double parseToDouble(String? text) {
    if (text == null || text.trim().isEmpty) return 0.0;
    final digits = text.replaceAll('.', '').trim();
    return double.tryParse(digits) ?? 0.0;
  }

  /// Parse teks dengan pemisah titik menjadi int murni
  /// Contoh: parseToInt("18.000") -> 18000
  static int parseToInt(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final digits = text.replaceAll('.', '').trim();
    return int.tryParse(digits) ?? 0;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String textToProcess = newValue.text;

    // 1. Tangani jika user menekan backspace tepat pada pemisah titik '.'
    // Jika selisih panjang berkurang 1 dan digit angka tidak berubah (artinya titik yang terhapus)
    if (oldValue.text.length - newValue.text.length == 1 &&
        oldValue.text.replaceAll('.', '') == newValue.text.replaceAll('.', '') &&
        oldValue.selection.baseOffset > newValue.selection.baseOffset) {
      final int posToDelete = newValue.selection.baseOffset - 1;
      if (posToDelete >= 0 && posToDelete < newValue.text.length) {
        textToProcess = newValue.text.substring(0, posToDelete) +
            newValue.text.substring(posToDelete + 1);
      }
    }

    // 2. Ekstrak digit angka saja
    String digits = textToProcess.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // 3. Batasi digit maksimum
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    // 4. Hilangkan leading zero jika panjang > 1
    while (digits.length > 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // 5. Format dengan titik ribuan
    final formatted = formatString(digits);

    // 6. Hitung posisi kursor secara presisi berdasarkan jumlah digit di kiri kursor
    int digitsBeforeCursor = 0;
    final int rawCursorPos = newValue.selection.baseOffset;
    for (int i = 0; i < rawCursorPos && i < textToProcess.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(textToProcess[i])) {
        digitsBeforeCursor++;
      }
    }

    int newCursorPos = 0;
    int digitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorPos = i + 1;
        break;
      }
    }

    if (newCursorPos > formatted.length || digitsBeforeCursor > digits.length) {
      newCursorPos = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}
