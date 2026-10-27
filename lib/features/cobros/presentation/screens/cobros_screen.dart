import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../creditos/presentation/screens/credito_detalle_screen.dart';
import '../../../creditos/providers/creditos_provider.dart';
import '../../../sistemas/presentation/widgets/estado_servicio_dialog.dart';
import '../../../sistemas/providers/sistemas_provider.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../data/cobro_model.dart';
import '../../providers/cobros_provider.dart';
import '../widgets/cobro_dialogs.dart';

final _moneda = NumberFormat.currency(locale: 'en_US', symbol: 'L.');
final _fecha = DateFormat('dd/MM/yyyy');

String _textoPlazo(CobroModel c) {
  final d = c.diasParaVencer;
  if (d < 0) return 'VENCIDO HACE ${-d} ${-d == 1 ? 'DÍA' : 'DÍAS'}';
  if (d == 0) return 'VENCE HOY';
  if (d == 1) return 'VENCE MAÑANA';
  return 'EN $d DÍAS';
}

Color _colorEstado(EstadoCobro e) {
  switch (e) {
    case EstadoCobro.vencido:
      return AppColors.error;
    case EstadoCobro.hoy:
      return AppColors.advertencia;
    case EstadoCobro.proximo:
      return AppColors.acento;
    case EstadoCobro.lejano:
      return AppColors.textoSecundario;
  }
}

class CobrosScreen extends ConsumerWidget {
  const CobrosScreen({super.key});

  void _refrescar(WidgetRef ref) {
    ref.invalidate(cobrosProvider);
    ref.invalidate(creditosProvider);
    ref.invalidate(resumenDashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosAsync = ref.watch(cobrosProvider);

    return cobrosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
        ),
      ),
      data: (cobros) {
        if (cobros.isEmpty) {
          return const Center(
            child: Text('SIN COBROS PENDIENTES', style: TextStyle(color: AppColors.textoSecundario)),
          );
        }

        final vencidos = cobros.where((c) => c.estado == EstadoCobro.vencido).toList();
        final hoy = cobros.where((c) => c.estado == EstadoCobro.hoy).toList();
        final proximos = cobros.where((c) => c.estado == EstadoCobro.proximo).toList();
        final lejanos = cobros.where((c) => c.estado == EstadoCobro.lejano).toList();
        final totalVencido = vencidos.fold<double>(0, (a, c) => a + c.monto);
        final totalSemana = [...hoy, ...proximos].fold<double>(0, (a, c) => a + c.monto);

        return RefreshIndicator(
          onRefresh: () async => _refrescar(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Resumen(
                      titulo: 'VENCIDO',
                      valor: _moneda.format(totalVencido),
                      detalle: '${vencidos.length} ${vencidos.length == 1 ? 'COBRO' : 'COBROS'}',
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Resumen(
                      titulo: 'HOY Y PRÓXIMOS 7 DÍAS',
                      valor: _moneda.format(totalSemana),
                      detalle: '${hoy.length + proximos.length} ${hoy.length + proximos.length == 1 ? 'COBRO' : 'COBROS'}',
                      color: AppColors.acento,
                    ),
                  ),
                ],
              ),
              _Grupo(titulo: 'VENCIDOS', cobros: vencidos, onCambio: () => _refrescar(ref)),
              _Grupo(titulo: 'VENCEN HOY', cobros: hoy, onCambio: () => _refrescar(ref)),
              _Grupo(titulo: 'PRÓXIMOS 7 DÍAS', cobros: proximos, onCambio: () => _refrescar(ref)),
              _Grupo(titulo: 'MÁS ADELANTE', cobros: lejanos, onCambio: () => _refrescar(ref)),
            ],
          ),
        );
      },
    );
  }
}

class _Resumen extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalle;
  final Color color;
  const _Resumen({required this.titulo, required this.valor, required this.detalle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Text(valor, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
            const SizedBox(height: 2),
            Text(detalle, style: const TextStyle(color: AppColors.textoTerciario, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  final String titulo;
  final List<CobroModel> cobros;
  final VoidCallback onCambio;
  const _Grupo({required this.titulo, required this.cobros, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    if (cobros.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(
            '$titulo · ${cobros.length}',
            style: const TextStyle(color: AppColors.textoTerciario, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
        for (final c in cobros) _TarjetaCobro(cobro: c, onCambio: onCambio),
      ],
    );
  }
}

class _TarjetaCobro extends ConsumerWidget {
  final CobroModel cobro;
  final VoidCallback onCambio;
  const _TarjetaCobro({required this.cobro, required this.onCambio});

  Future<void> _abrirEstadoServicio(BuildContext context, WidgetRef ref) async {
    final ventas = await ref.read(sistemasClienteProvider(null).future);
    final coincidencias = ventas.where((v) => v.id == cobro.ventaId);
    if (coincidencias.isEmpty || !context.mounted) return;
    final cambiado = await showDialog<bool>(
      context: context,
      builder: (_) => EstadoServicioDialog(venta: coincidencias.first),
    );
    if (cambiado == true) {
      ref.invalidate(sistemasClienteProvider(null));
      onCambio();
    }
  }

  Future<void> _abrirHistorial(BuildContext context, WidgetRef ref) async {
    final creditos = await ref.read(creditosProvider.future);
    final coincidencias = creditos.where((c) => c.id == cobro.creditoId);
    if (coincidencias.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreditoDetalleScreen(credito: coincidencias.first)),
    );
    onCambio();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorEstado(cobro.estado);
    final detalle = cobro.esSuscripcion
        ? '${cobro.concepto.toUpperCase()} · MENSUALIDAD'
        : '${cobro.concepto.toUpperCase()} · CUOTA ${cobro.numeroCuota}/${cobro.totalCuotas}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cobro.clienteNombre.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Text(_moneda.format(cobro.monto), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(detalle, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_fecha.format(cobro.fechaVencimiento)} · ${_textoPlazo(cobro)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
                if (cobro.saldoPendiente > cobro.monto + 0.005)
                  Text(
                    'DEBE ${_moneda.format(cobro.saldoPendiente)}',
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => RegistrarPagoCobroDialog(cobro: cobro),
                      );
                      if (ok == true) onCambio();
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('MARCAR PAGADO'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => CambiarFechaCobroDialog(cobro: cobro),
                    );
                    if (ok == true) onCambio();
                  },
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: const Text('FECHA'),
                ),
                IconButton(
                  tooltip: 'Historial de pagos',
                  icon: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.textoSecundario),
                  onPressed: () => _abrirHistorial(context, ref),
                ),
                if (cobro.ventaId != null)
                  IconButton(
                    tooltip: 'Estado del sistema del cliente',
                    icon: Icon(
                      cobro.estadoServicio == 'bloqueado' ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 20,
                      color: colorEstadoServicio(cobro.estadoServicio ?? 'activo'),
                    ),
                    onPressed: () => _abrirEstadoServicio(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
