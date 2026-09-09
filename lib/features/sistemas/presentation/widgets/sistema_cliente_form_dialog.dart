import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../data/sistema_cliente_model.dart';
import '../../providers/sistemas_provider.dart';

final _fechaFmt = DateFormat('dd/MM/yyyy');

class SistemaClienteFormDialog extends ConsumerStatefulWidget {
  final SistemaClienteModel? existente;
  const SistemaClienteFormDialog({super.key, this.existente});

  @override
  ConsumerState<SistemaClienteFormDialog> createState() => _SistemaClienteFormDialogState();
}

class _SistemaClienteFormDialogState extends ConsumerState<SistemaClienteFormDialog> {
  String? _clienteId;
  String? _sistemaId;
  String _tipoVenta = 'contado';
  late DateTime _fechaVenta;
  DateTime? _fechaPrimerPago;
  final _montoCtrl = TextEditingController();
  final _pagoInicialCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController();
  final _montoMensualCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _fechaVenta = e?.fechaVenta ?? DateTime.now();
    if (e != null) {
      _clienteId = e.clienteId;
      _sistemaId = e.sistemaId;
      _tipoVenta = e.tipoVenta;
      _fechaPrimerPago = e.fechaPrimerPago;
      if (e.montoTotal != null) _montoCtrl.text = e.montoTotal!.toStringAsFixed(2);
      if (e.pagoInicial != null) _pagoInicialCtrl.text = e.pagoInicial!.toStringAsFixed(2);
      if (e.numeroCuotas != null) _cuotasCtrl.text = e.numeroCuotas!.toString();
      if (e.montoMensual != null) _montoMensualCtrl.text = e.montoMensual!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _pagoInicialCtrl.dispose();
    _cuotasCtrl.dispose();
    _montoMensualCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({required DateTime? actual, required ValueChanged<DateTime> onElegida}) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) onElegida(elegida);
  }

  Future<void> _guardar() async {
    if (_clienteId == null || _sistemaId == null) {
      setState(() => _error = 'Completá cliente y sistema');
      return;
    }

    final esMensualidades = _tipoVenta == 'mensualidades';
    final esSuscripcion = _tipoVenta == 'suscripcion';

    double? montoTotal;
    int? cuotas;
    double? montoMensual;

    if (esSuscripcion) {
      montoMensual = double.tryParse(_montoMensualCtrl.text.trim());
      if (montoMensual == null || montoMensual <= 0) {
        setState(() => _error = 'Indicá el monto de la mensualidad');
        return;
      }
    } else {
      montoTotal = double.tryParse(_montoCtrl.text.trim());
      if (montoTotal == null) {
        setState(() => _error = 'Indicá el monto total');
        return;
      }
      if (esMensualidades) {
        cuotas = int.tryParse(_cuotasCtrl.text.trim());
        if (cuotas == null || cuotas <= 0) {
          setState(() => _error = 'Indicá el número de cuotas');
          return;
        }
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(sistemasRepositoryProvider);
      final pagoInicial = (esMensualidades || esSuscripcion) ? double.tryParse(_pagoInicialCtrl.text.trim()) : null;
      final fechaPrimerPago = (esMensualidades || esSuscripcion) ? _fechaPrimerPago : null;

      if (_editando) {
        await repo.editarSistemaCliente(
          id: widget.existente!.id,
          clienteId: _clienteId!,
          sistemaId: _sistemaId!,
          fechaVenta: _fechaVenta,
          tipoVenta: _tipoVenta,
          montoTotal: montoTotal,
          pagoInicial: pagoInicial,
          numeroCuotas: esMensualidades ? cuotas : null,
          montoMensual: esSuscripcion ? montoMensual : null,
          fechaPrimerPago: fechaPrimerPago,
        );
      } else {
        await repo.venderSistema(
          clienteId: _clienteId!,
          sistemaId: _sistemaId!,
          fechaVenta: _fechaVenta,
          tipoVenta: _tipoVenta,
          montoTotal: montoTotal,
          pagoInicial: pagoInicial,
          numeroCuotas: esMensualidades ? cuotas : null,
          montoMensual: esSuscripcion ? montoMensual : null,
          fechaPrimerPago: fechaPrimerPago,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'No se pudo guardar: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesProvider);
    final catalogoAsync = ref.watch(catalogoSistemasProvider);
    final esMensualidades = _tipoVenta == 'mensualidades';
    final esSuscripcion = _tipoVenta == 'suscripcion';

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_editando ? 'EDITAR VENTA' : 'VENDER SISTEMA'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              clientesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('NO SE PUDO CARGAR CLIENTES', style: TextStyle(color: AppColors.error)),
                data: (clientes) {
                  final coincide = clientes.any((c) => c.id == _clienteId);
                  return DropdownButtonFormField<String>(
                    initialValue: coincide ? _clienteId : null,
                    decoration: const InputDecoration(hintText: 'CLIENTE'),
                    dropdownColor: AppColors.superficieAlta,
                    items: clientes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombreNegocio))).toList(),
                    onChanged: (v) => setState(() => _clienteId = v),
                  );
                },
              ),
              const SizedBox(height: 10),
              catalogoAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('NO SE PUDO CARGAR CATÁLOGO', style: TextStyle(color: AppColors.error)),
                data: (catalogo) {
                  final coincide = catalogo.any((s) => s.id == _sistemaId);
                  return DropdownButtonFormField<String>(
                    initialValue: coincide ? _sistemaId : null,
                    decoration: const InputDecoration(hintText: 'SISTEMA'),
                    dropdownColor: AppColors.superficieAlta,
                    items: catalogo.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre))).toList(),
                    onChanged: (v) => setState(() => _sistemaId = v),
                  );
                },
              ),
              const SizedBox(height: 10),
              _CampoFecha(
                etiqueta: 'FECHA DE VENTA',
                fecha: _fechaVenta,
                onTap: () => _elegirFecha(actual: _fechaVenta, onElegida: (f) => setState(() => _fechaVenta = f)),
              ),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: _tipoVenta,
                onChanged: (v) => setState(() => _tipoVenta = v!),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'contado',
                      title: const Text('CONTADO', style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    RadioListTile<String>(
                      value: 'mensualidades',
                      title: const Text('MENSUALIDADES (CUOTAS FIJAS)', style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    RadioListTile<String>(
                      value: 'suscripcion',
                      title: const Text('SUSCRIPCIÓN (MENSUALIDAD INDEFINIDA)', style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (!esSuscripcion) ...[
                TextField(
                  controller: _montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'MONTO TOTAL *'),
                ),
                const SizedBox(height: 10),
              ],
              if (esMensualidades || esSuscripcion) ...[
                TextField(
                  controller: _pagoInicialCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'PAGO INICIAL (OPCIONAL)'),
                ),
                const SizedBox(height: 10),
              ],
              if (esMensualidades)
                TextField(
                  controller: _cuotasCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'NÚMERO DE CUOTAS *'),
                ),
              if (esSuscripcion)
                TextField(
                  controller: _montoMensualCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'MENSUALIDAD *'),
                ),
              if (esMensualidades || esSuscripcion) ...[
                const SizedBox(height: 10),
                _CampoFecha(
                  etiqueta: 'FECHA DEL PRIMER PAGO (OPCIONAL)',
                  fecha: _fechaPrimerPago,
                  onTap: () => _elegirFecha(
                    actual: _fechaPrimerPago,
                    onElegida: (f) => setState(() => _fechaPrimerPago = f),
                  ),
                  onLimpiar: _fechaPrimerPago != null ? () => setState(() => _fechaPrimerPago = null) : null,
                ),
                const SizedBox(height: 6),
                Text(
                  esSuscripcion
                      ? 'SI NO LA ELEGÍS, LA MENSUALIDAD EMPIEZA A CONTAR DESDE HOY.'
                      : 'SI NO LA ELEGÍS, LA PRIMERA CUOTA VENCE UN MES DESPUÉS DE LA FECHA DE VENTA.',
                  style: const TextStyle(color: AppColors.textoTerciario, fontSize: 11),
                ),
              ],
              if (_editando) ...[
                const SizedBox(height: 8),
                const Text(
                  'SI EL CLIENTE YA HIZO ALGÚN ABONO, LOS MONTOS Y CUOTAS QUEDAN COMO ESTABAN (SOLO SE ACTUALIZAN LOS DATOS GENERALES).',
                  style: TextStyle(color: AppColors.textoTerciario, fontSize: 11),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('GUARDAR'),
        ),
      ],
    );
  }
}

class _CampoFecha extends StatelessWidget {
  final String etiqueta;
  final DateTime? fecha;
  final VoidCallback onTap;
  final VoidCallback? onLimpiar;

  const _CampoFecha({required this.etiqueta, required this.fecha, required this.onTap, this.onLimpiar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: etiqueta,
          suffixIcon: onLimpiar != null
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onLimpiar)
              : const Icon(Icons.calendar_today_rounded, size: 16),
        ),
        child: Text(
          fecha != null ? _fechaFmt.format(fecha!) : 'SIN ELEGIR',
          style: TextStyle(color: fecha != null ? AppColors.textoPrimario : AppColors.textoTerciario),
        ),
      ),
    );
  }
}
