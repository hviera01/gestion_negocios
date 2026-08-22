import 'package:flutter/material.dart';

enum Seccion {
  dashboard(label: 'DASHBOARD', icono: Icons.dashboard_rounded),
  clientes(label: 'CLIENTES', icono: Icons.people_alt_rounded),
  sistemas(label: 'SISTEMAS VENDIDOS', icono: Icons.apps_rounded),
  trabajos(label: 'TRABAJOS', icono: Icons.build_rounded),
  creditos(label: 'CRÉDITOS', icono: Icons.account_balance_wallet_rounded),
  reportes(label: 'REPORTES DE FALLOS', icono: Icons.bug_report_rounded);

  final String label;
  final IconData icono;
  const Seccion({required this.label, required this.icono});
}
