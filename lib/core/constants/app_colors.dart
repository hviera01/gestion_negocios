import 'package:flutter/material.dart';

/// Paleta oscura de gestion_negocios. Deliberadamente distinta al navy/dorado
/// y navy/azul que ya usan Lopsi/Barbería/Autofrenos/CapitalExpress.
class AppColors {
  AppColors._();

  static const Color fondo = Color(0xFF0B0F17);
  static const Color fondoElevado = Color(0xFF121826);
  static const Color superficie = Color(0xFF171F30);
  static const Color superficieAlta = Color(0xFF1E2740);

  static const Color acento = Color(0xFF5EEAD4); // teal eléctrico
  static const Color acentoVioleta = Color(0xFFA78BFA);

  static const Color textoPrimario = Color(0xFFF3F5F9);
  static const Color textoSecundario = Color(0xFF9AA5B8);
  static const Color textoTerciario = Color(0xFF64708A);

  static const Color borde = Color(0xFF232D45);

  static const Color exito = Color(0xFF34D399);
  static const Color advertencia = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);

  static const List<Color> gradienteMesh = [
    Color(0xFF1B2A4A),
    Color(0xFF3B2A5C),
    Color(0xFF0F1D33),
  ];
}
