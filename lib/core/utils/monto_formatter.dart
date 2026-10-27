import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _formato = NumberFormat('#,##0.00', 'en_US');

String textoMonto(double valor) => 'L.${_formato.format(valor)}';

double? parsearMonto(String texto) {
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return null;
  return int.parse(digitos) / 100;
}

/// Los dígitos que se teclean entran como centavos: 1 2 0 0 0 0 -> L.1,200.00
class MontoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final valor = parsearMonto(newValue.text) ?? 0;
    final texto = textoMonto(valor);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
