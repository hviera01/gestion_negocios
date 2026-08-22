import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/creditos_provider.dart';
import '../widgets/credito_manual_form_dialog.dart';
import 'credito_detalle_screen.dart';

final _moneda = NumberFormat.currency(locale: 'es_HN', symbol: 'L. ');

class CreditosScreen extends ConsumerWidget {
  const CreditosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditosAsync = ref.watch(creditosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await showDialog<bool>(context: context, builder: (_) => const CreditoManualFormDialog());
          if (creado == true) ref.invalidate(creditosProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('CRÉDITO MANUAL'),
      ),
      body: creditosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (creditos) {
          if (creditos.isEmpty) {
            return const Center(child: Text('SIN CRÉDITOS REGISTRADOS', style: TextStyle(color: AppColors.textoSecundario)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: creditos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = creditos[i];
              final pendiente = c.saldoPendiente > 0;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(
                    c.vencido ? Icons.error_rounded : (pendiente ? Icons.hourglass_bottom_rounded : Icons.check_circle_rounded),
                    color: c.vencido ? AppColors.error : (pendiente ? AppColors.advertencia : AppColors.exito),
                  ),
                  title: Text(_moneda.format(c.saldoPendiente), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'ORIGEN: ${c.origen.toUpperCase()} · TOTAL ${_moneda.format(c.montoTotal)}',
                    style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textoTerciario),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CreditoDetalleScreen(credito: c)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
