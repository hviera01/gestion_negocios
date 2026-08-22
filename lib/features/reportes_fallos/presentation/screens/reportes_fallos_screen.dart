import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/reporte_fallo_model.dart';
import '../../providers/reportes_fallos_provider.dart';
import '../widgets/convertir_trabajo_dialog.dart';
import '../widgets/reporte_fallo_form_dialog.dart';

final _fecha = DateFormat('dd/MM/yyyy');

class ReportesFallosScreen extends ConsumerWidget {
  const ReportesFallosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportesAsync = ref.watch(reportesFallosProvider);
    final filtro = ref.watch(filtroEstadoReportesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await showDialog<bool>(context: context, builder: (_) => const ReporteFalloFormDialog());
          if (creado == true) ref.invalidate(reportesFallosProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('NUEVO REPORTE'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _chipFiltro(ref, 'TODOS', null, filtro),
                _chipFiltro(ref, 'ABIERTOS', 'abierto', filtro),
                _chipFiltro(ref, 'EN PROGRESO', 'en_progreso', filtro),
                _chipFiltro(ref, 'RESUELTOS', 'resuelto', filtro),
              ],
            ),
          ),
          Expanded(
            child: reportesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data: (reportes) {
                if (reportes.isEmpty) {
                  return const Center(child: Text('SIN REPORTES', style: TextStyle(color: AppColors.textoSecundario)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: reportes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _TarjetaReporte(reporte: reportes[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(WidgetRef ref, String label, String? valor, String? actual) {
    return ChoiceChip(
      label: Text(label),
      selected: actual == valor,
      onSelected: (_) => ref.read(filtroEstadoReportesProvider.notifier).seleccionar(valor),
    );
  }
}

class _TarjetaReporte extends ConsumerWidget {
  final ReporteFalloModel reporte;
  const _TarjetaReporte({required this.reporte});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'resuelto':
        return AppColors.exito;
      case 'en_progreso':
        return AppColors.advertencia;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(reportesFallosRepositoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(reporte.descripcion.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
                Chip(
                  label: Text(reporte.estado.toUpperCase(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: _colorEstado(reporte.estado).withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: _colorEstado(reporte.estado)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_fecha.format(reporte.fechaReporte)} · ${reporte.cobrado ? 'COBRADO' : 'GRATIS'}',
              style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (reporte.estado != 'en_progreso' && reporte.estado != 'resuelto')
                  OutlinedButton(
                    onPressed: () async {
                      await repo.actualizar(id: reporte.id, estado: 'en_progreso');
                      ref.invalidate(reportesFallosProvider);
                    },
                    child: const Text('EN PROGRESO'),
                  ),
                if (reporte.estado != 'resuelto')
                  OutlinedButton(
                    onPressed: () async {
                      await repo.actualizar(id: reporte.id, estado: 'resuelto');
                      ref.invalidate(reportesFallosProvider);
                    },
                    child: const Text('MARCAR RESUELTO'),
                  ),
                if (reporte.sistemaClienteId != null)
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => ConvertirTrabajoDialog(reporte: reporte),
                      );
                      if (ok == true) ref.invalidate(reportesFallosProvider);
                    },
                    child: const Text('CONVERTIR EN TRABAJO'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
