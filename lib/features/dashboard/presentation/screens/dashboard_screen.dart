import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../providers/dashboard_provider.dart';

final _moneda = NumberFormat.currency(locale: 'es_HN', symbol: 'L. ');

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenDashboardProvider);

    return resumenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      data: (resumen) {
        final saldoPendiente = (resumen['saldo_pendiente_total'] as num?)?.toDouble() ?? 0;
        final reportesAbiertos = resumen['reportes_abiertos'] as int? ?? 0;
        final totalClientes = resumen['total_clientes'] as int? ?? 0;
        final creditosVencidos = resumen['creditos_vencidos'] as int? ?? 0;
        final columnas = esEscritorio(context) ? 4 : 2;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(resumenDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GridView.count(
                crossAxisCount: columnas,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _TarjetaKpi(titulo: 'SALDO PENDIENTE', valor: _moneda.format(saldoPendiente), color: AppColors.advertencia, icono: Icons.account_balance_wallet_rounded),
                  _TarjetaKpi(titulo: 'CRÉDITOS VENCIDOS', valor: '$creditosVencidos', color: AppColors.error, icono: Icons.error_rounded),
                  _TarjetaKpi(titulo: 'REPORTES ABIERTOS', valor: '$reportesAbiertos', color: AppColors.acentoVioleta, icono: Icons.bug_report_rounded),
                  _TarjetaKpi(titulo: 'CLIENTES', valor: '$totalClientes', color: AppColors.acento, icono: Icons.people_alt_rounded),
                ],
              ),
              const SizedBox(height: 24),
              const Text('ABONOS RECIENTES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              ..._abonosRecientes(resumen),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _abonosRecientes(Map<String, dynamic> resumen) {
    final abonos = resumen['abonos_recientes'] as List? ?? [];
    if (abonos.isEmpty) {
      return [const Text('SIN ABONOS RECIENTES', style: TextStyle(color: AppColors.textoTerciario))];
    }
    return abonos
        .map((a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.arrow_downward_rounded, color: AppColors.exito),
                title: Text(_moneda.format((a['monto_abonado'] as num?)?.toDouble() ?? 0)),
                subtitle: Text(a['metodo_pago'] as String? ?? 'sin método', style: const TextStyle(fontSize: 12)),
              ),
            ))
        .toList();
  }
}

class _TarjetaKpi extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;
  final IconData icono;
  const _TarjetaKpi({required this.titulo, required this.valor, required this.color, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icono, color: color, size: 22),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(titulo, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
