import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/clientes_provider.dart';
import '../widgets/cliente_form_dialog.dart';
import 'cliente_detalle_screen.dart';

class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await showDialog<bool>(
            context: context,
            builder: (_) => const ClienteFormDialog(),
          );
          if (creado == true) ref.invalidate(clientesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('NUEVO CLIENTE'),
      ),
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (clientes) {
          if (clientes.isEmpty) {
            return const Center(
              child: Text('TODAVÍA NO REGISTRASTE NINGÚN CLIENTE', style: TextStyle(color: AppColors.textoSecundario)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: clientes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = clientes[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.acento.withValues(alpha: 0.15),
                    child: Text(
                      c.nombreNegocio.isNotEmpty ? c.nombreNegocio[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.acento, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(c.nombreNegocio, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [if (c.nombreContacto != null) c.nombreContacto!, if (c.telefono != null) c.telefono!].join(' · '),
                    style: const TextStyle(color: AppColors.textoSecundario),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textoTerciario),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ClienteDetalleScreen(clienteId: c.id, nombre: c.nombreNegocio)),
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
