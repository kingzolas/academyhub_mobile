import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';

class ExpenseCategoryStyle {
  final IconData icon;
  final Color color;
  final Color bgColor;

  ExpenseCategoryStyle(this.icon, this.color, this.bgColor);

  static ExpenseCategoryStyle getStyle(String category) {
    switch (category) {
      case 'Energia':
        return ExpenseCategoryStyle(PhosphorIcons.lightning_fill,
            Colors.amber[700]!, Colors.amber[50]!);
      case 'Água':
        return ExpenseCategoryStyle(
            PhosphorIcons.drop_fill, Colors.blue[600]!, Colors.blue[50]!);
      case 'Internet':
        return ExpenseCategoryStyle(
            PhosphorIcons.wifi_high_bold, Colors.cyan[600]!, Colors.cyan[50]!);
      case 'Pessoal':
        return ExpenseCategoryStyle(PhosphorIcons.users_three_fill,
            Colors.purple[600]!, Colors.purple[50]!);
      case 'Vale/Adiantamento':
        return ExpenseCategoryStyle(
            PhosphorIcons.hand_soap_fill,
            Colors.redAccent[700]!,
            Colors.red[
                50]!); // Cor de destaque para saída de dinheiro de funcionário
      case 'Aluguel':
        return ExpenseCategoryStyle(PhosphorIcons.house_line_fill,
            Colors.indigo[600]!, Colors.indigo[50]!);
      case 'Manutenção':
        return ExpenseCategoryStyle(
            PhosphorIcons.wrench_fill, Colors.brown[600]!, Colors.brown[50]!);
      case 'Marketing':
        return ExpenseCategoryStyle(
            PhosphorIcons.megaphone_fill, Colors.pink[600]!, Colors.pink[50]!);
      case 'Impostos':
        return ExpenseCategoryStyle(PhosphorIcons.bank_fill,
            Colors.blueGrey[700]!, Colors.blueGrey[50]!);
      default:
        return ExpenseCategoryStyle(
            PhosphorIcons.tag_fill, Colors.grey[600]!, Colors.grey[100]!);
    }
  }
}
