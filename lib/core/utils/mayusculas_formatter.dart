import 'package:flutter/services.dart';

/// Fuerza mayúsculas mientras se escribe (no solo el hint visual del teclado
/// móvil) — se usa en todos los campos de texto libre de la app.
class MayusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
