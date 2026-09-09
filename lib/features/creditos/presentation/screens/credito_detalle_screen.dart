import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/credito_model.dart';
import '../../providers/creditos_provider.dart';
import '../widgets/registrar_abono_dialog.dart';

final _moneda = NumberFormat.currency(locale: 'en_US', symbol: 'L.');
final _fecha = DateFormat('dd/MM/yyyy');

class CreditoDetalleScreen extends ConsumerWidget {
  final CreditoModel credito;
  const CreditoDetalleScreen({super.key, required this.credito});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuotasAsync = ref.watch(cuotasCreditoProvider(credito.id));
    final abonosAsync = ref.watch(abonosCreditoProvider(credito.id));

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: Text('SALDO ${_moneda.format(credito.saldoPendiente)}')),
      floatingActionButton: credito.saldoPendiente > 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final registrado = await showDialog<bool>(
                  context: context,
                  builder: (_) => RegistrarAbonoDialog(credito: credito),
                );
                if (registrado == true) {
                  ref.invalidate(cuotasCreditoProvider(credito.id));
                  ref.invalidate(abonosCreditoProvider(credito.id));
                  ref.invalidate(creditosProvider);
                }
              },
              icon: const Icon(Icons.payments_rounded),
              label: const Text('REGISTRAR ABONO'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'INICIÓ EL ${_fecha.format(credito.fechaRegistro)}'
              '${credito.fechaVencimiento != null ? ' · VENCE ${_fecha.format(credito.fechaVencimiento!)}' : ''}',
              style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
            ),
          ),
          cuotasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (cuotas) {
              if (cuotas.isEmpty) return const SizedBox.shrink();
              final hoy = DateTime.now();
              final pendientes = cuotas.where((c) => !c.pagada).toList()
                ..sort((a, b) => a.numero.compareTo(b.numero));
              final proxima = pendientes.isEmpty ? null : pendientes.first;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CUOTAS', style: TextStyle(fontWeight: FontWeight.w700)),
                      if (proxima != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (proxima.fechaVencimiento.isBefore(hoy) ? AppColors.error : AppColors.advertencia)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${proxima.fechaVencimiento.isBefore(hoy) ? 'VENCIDA' : 'PRÓXIMO PAGO'}: '
                            '${_moneda.format(proxima.monto)} · ${_fecha.format(proxima.fechaVencimiento)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: proxima.fechaVencimiento.isBefore(hoy) ? AppColors.error : AppColors.advertencia,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cuotas.map((c) {
                          final vencida = !c.pagada && c.fechaVencimiento.isBefore(hoy);
                          final color = c.pagada ? AppColors.exito : (vencida ? AppColors.error : AppColors.advertencia);
                          return Chip(
                            label: Text('#${c.numero} · ${_moneda.format(c.monto)} · ${_fecha.format(c.fechaVencimiento)}'),
                            avatar: Icon(
                              c.pagada ? Icons.check_circle : (vencida ? Icons.error : Icons.schedule),
                              size: 16,
                              color: color,
                            ),
                            backgroundColor: color.withValues(alpha: 0.12),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('HISTORIAL DE ABONOS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          abonosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error)),
            data: (abonos) {
              if (abonos.isEmpty) {
                return const Text('SIN ABONOS TODAVÍA', style: TextStyle(color: AppColors.textoTerciario));
              }
              return esEscritorio(context) ? _TablaAbonos(abonos: abonos) : _ListaAbonosMovil(abonos: abonos);
            },
          ),
        ],
      ),
    );
  }
}

class _TablaAbonos extends StatelessWidget {
  final List<AbonoModel> abonos;
  const _TablaAbonos({required this.abonos});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('FECHA')),
            DataColumn(label: Text('MONTO ABONADO')),
            DataColumn(label: Text('SALDO ANTERIOR')),
            DataColumn(label: Text('INTERÉS')),
            DataColumn(label: Text('SALDO PENDIENTE')),
            DataColumn(label: Text('MÉTODO')),
          ],
          rows: abonos
              .map((a) => DataRow(cells: [
                    DataCell(Text(_fecha.format(a.fecha))),
                    DataCell(Text(_moneda.format(a.montoAbonado))),
                    DataCell(Text(_moneda.format(a.saldoAnterior))),
                    DataCell(Text(_moneda.format(a.interes))),
                    DataCell(Text(_moneda.format(a.saldoPendiente))),
                    DataCell(Text(a.metodoPago ?? '-')),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

class _ListaAbonosMovil extends StatelessWidget {
  final List<AbonoModel> abonos;
  const _ListaAbonosMovil({required this.abonos});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: abonos
          .map((a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(_moneda.format(a.montoAbonado), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${_fecha.format(a.fecha)} · ${a.metodoPago ?? 'sin método'}'),
                  trailing: Text('SALDO: ${_moneda.format(a.saldoPendiente)}', style: const TextStyle(fontSize: 12)),
                ),
              ))
          .toList(),
    );
  }
}
