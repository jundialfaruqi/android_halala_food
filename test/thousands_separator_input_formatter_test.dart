import 'package:android_halala_food/core/utils/thousands_separator_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThousandsSeparatorInputFormatter Tests', () {
    const formatter = ThousandsSeparatorInputFormatter();

    test('format static method formats numbers correctly', () {
      expect(ThousandsSeparatorInputFormatter.format(0), '0');
      expect(ThousandsSeparatorInputFormatter.format(500), '500');
      expect(ThousandsSeparatorInputFormatter.format(1000), '1.000');
      expect(ThousandsSeparatorInputFormatter.format(18000), '18.000');
      expect(ThousandsSeparatorInputFormatter.format(150000), '150.000');
      expect(ThousandsSeparatorInputFormatter.format(1500000), '1.500.000');
    });

    test('parseToDouble and parseToInt parse dot-separated strings correctly', () {
      expect(ThousandsSeparatorInputFormatter.parseToDouble('18.000'), 18000.0);
      expect(ThousandsSeparatorInputFormatter.parseToDouble('1.500.000'), 1500000.0);
      expect(ThousandsSeparatorInputFormatter.parseToDouble(''), 0.0);
      expect(ThousandsSeparatorInputFormatter.parseToDouble(null), 0.0);

      expect(ThousandsSeparatorInputFormatter.parseToInt('18.000'), 18000);
      expect(ThousandsSeparatorInputFormatter.parseToInt('1.500.000'), 1500000);
      expect(ThousandsSeparatorInputFormatter.parseToInt(''), 0);
      expect(ThousandsSeparatorInputFormatter.parseToInt(null), 0);
    });

    test('formatEditUpdate inserts dots as digits are typed', () {
      const oldValue = TextEditingValue.empty;

      final res1 = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: '1800',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(res1.text, '1.800');
      expect(res1.selection.baseOffset, 5);

      final res2 = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: '18000',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(res2.text, '18.000');
      expect(res2.selection.baseOffset, 6);
    });

    test('formatEditUpdate handles backspace on dot cleanly', () {
      const oldValue = TextEditingValue(
        text: '1.800',
        selection: TextSelection.collapsed(offset: 2), // cursor right after dot: "1.|800"
      );

      // User presses backspace on dot -> dot deleted, resulting text "1800"
      final res = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: '1800',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );

      // Should delete '1', leaving '800'
      expect(res.text, '800');
    });
  });
}
