import 'package:flutter/material.dart';

import '../../features/clientes/presentation/screens/clientes_screen.dart';
import '../../features/creditos/presentation/screens/creditos_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/reportes_fallos/presentation/screens/reportes_fallos_screen.dart';
import '../../features/sistemas/presentation/screens/sistemas_screen.dart';
import '../../features/trabajos/presentation/screens/trabajos_screen.dart';
import '../models/seccion.dart';

Widget construirBodySeccion(Seccion seccion) {
  switch (seccion) {
    case Seccion.dashboard:
      return const DashboardScreen();
    case Seccion.clientes:
      return const ClientesScreen();
    case Seccion.sistemas:
      return const SistemasScreen();
    case Seccion.trabajos:
      return const TrabajosScreen();
    case Seccion.creditos:
      return const CreditosScreen();
    case Seccion.reportes:
      return const ReportesFallosScreen();
  }
}
