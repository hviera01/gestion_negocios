import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/trabajos_provider.dart';
import '../widgets/trabajo_form_dialog.dart';

final _moneda = NumberFormat.currency(locale: 'en_US', symbol: 'L.');
final _fecha = DateFormat('dd/MM/yyyy');

class TrabajosScreen extends ConsumerWidget {
  const TrabajosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trabajosAsync = ref.watch(trabajosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await showDialog<bool>(context: context, builder: (_) => const TrabajoFormDialog());
          if (creado == true) ref.invalidate(trabajosProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('NUEVO TRABAJO'),
      ),
      body: trabajosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (trabajos) {
          if (trabajos.isEmpty) {
            return const Center(child: Text('SIN TRABAJOS REGISTRADOS', style: TextStyle(color: AppColors.textoSecundario)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: trabajos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = trabajos[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(t.descripcion.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_fecha.format(t.fecha), style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        t.monto == 0 ? 'GRATIS' : _moneda.format(t.monto),
                        style: TextStyle(fontWeight: FontWeight.w700, color: t.monto == 0 ? AppColors.textoTerciario : AppColors.acento),
                      ),
                      if (t.esCredito)
                        const Text('A CRÉDITO', style: TextStyle(fontSize: 11, color: AppColors.advertencia)),
                    ],
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
