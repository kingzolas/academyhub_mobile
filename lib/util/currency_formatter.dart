import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // 1. Se estiver vazio, reseta
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // 2. Remove tudo que não for dígito
    double value = double.parse(newValue.text.replaceAll(RegExp('[^0-9]'), ''));

    // 3. Divide por 100 para criar os centavos
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String newText = formatter.format(value / 100);

    // 4. Retorna o novo valor mantendo o cursor no final
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}
