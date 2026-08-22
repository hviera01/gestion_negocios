import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/clientes_provider.dart';

final _moneda = NumberFormat.currency(locale: 'es_HN', symbol: 'L. ');

class ClienteDetalleScreen extends ConsumerWidget {
  final String clienteId;
  final String nombre;
  const ClienteDetalleScreen({super.key, required this.clienteId, required this.nombre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(detalleClienteProvider(clienteId));

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: Text(nombre.toUpperCase())),
      body: detalleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (detalle) {
          final sistemas = detalle['sistemas'] as List? ?? [];
          final trabajos = detalle['trabajos'] as List? ?? [];
          final creditos = detalle['creditos'] as List? ?? [];
          final reportes = detalle['reportes_fallos'] as List? ?? [];
          final saldoTotal = creditos.fold<double>(
            0,
            (acc, c) => acc + ((c['saldo_pendiente'] as num?)?.toDouble() ?? 0),
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (saldoTotal > 0)
                Card(
                  color: AppColors.error.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text('DEBE ${_moneda.format(saldoTotal)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: 'SISTEMAS VENDIDOS',
                vacio: 'SIN SISTEMAS REGISTRADOS',
                items: sistemas.map((s) => _fila(
                      titulo: (s['nombre'] as String? ?? '').toUpperCase(),
                      subtitulo: '${(s['tipo_venta'] as String? ?? '').toUpperCase()} · ${_moneda.format((s['monto_total'] as num?)?.toDouble() ?? 0)}',
                    )).toList(),
              ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: 'TRABAJOS',
                vacio: 'SIN TRABAJOS REGISTRADOS',
                items: trabajos.map((t) => _fila(
                      titulo: (t['descripcion'] as String? ?? '').toUpperCase(),
                      subtitulo: (t['monto'] as num?) == 0 ? 'GRATIS' : _moneda.format((t['monto'] as num?)?.toDouble() ?? 0),
                    )).toList(),
              ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: 'CRÉDITOS',
                vacio: 'SIN CRÉDITOS',
                items: creditos.map((c) => _fila(
                      titulo: 'SALDO: ${_moneda.format((c['saldo_pendiente'] as num?)?.toDouble() ?? 0)}',
                      subtitulo: 'ORIGEN: ${(c['origen'] as String? ?? '').toUpperCase()}',
                      destacado: ((c['saldo_pendiente'] as num?) ?? 0) > 0,
                    )).toList(),
              ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: 'REPORTES DE FALLOS',
                vacio: 'SIN REPORTES',
                items: reportes.map((r) => _fila(
                      titulo: (r['descripcion'] as String? ?? '').toUpperCase(),
                      subtitulo: '${(r['estado'] as String? ?? '').toUpperCase()}${(r['cobrado'] == true) ? ' · COBRADO' : ' · GRATIS'}',
                    )).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fila({required String titulo, required String subtitulo, bool destacado = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titulo, style: TextStyle(color: destacado ? AppColors.error : AppColors.textoPrimario)),
      subtitle: Text(subtitulo, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final String vacio;
  final List<Widget> items;
  const _Seccion({required this.titulo, required this.vacio, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Divider(height: 20),
            if (items.isEmpty)
              Text(vacio, style: const TextStyle(color: AppColors.textoTerciario, fontSize: 13))
            else
              ...items,
          ],
        ),
      ),
    );
  }
}
