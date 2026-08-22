import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reporte_fallo_model.dart';
import '../data/reportes_fallos_repository.dart';

final reportesFallosRepositoryProvider = Provider((ref) => ReportesFallosRepository());

final filtroEstadoReportesProvider = NotifierProvider<FiltroEstadoNotifier, String?>(FiltroEstadoNotifier.new);

class FiltroEstadoNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void seleccionar(String? estado) => state = estado;
}

final reportesFallosProvider = FutureProvider<List<ReporteFalloModel>>((ref) {
  final estado = ref.watch(filtroEstadoReportesProvider);
  return ref.watch(reportesFallosRepositoryProvider).listar(estado: estado);
});
