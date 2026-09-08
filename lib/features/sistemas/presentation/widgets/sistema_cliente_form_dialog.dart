import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/sistema_model.dart';
import '../../../clientes/data/cliente_model.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../providers/sistemas_provider.dart';

class SistemaClienteFormDialog extends ConsumerStatefulWidget {
  const SistemaClienteFormDialog({super.key});

  @override
  ConsumerState<SistemaClienteFormDialog> createState() => _SistemaClienteFormDialogState();
}

class _SistemaClienteFormDialogState extends ConsumerState<SistemaClienteFormDialog> {
  ClienteModel? _cliente;
  SistemaModel? _sistema;
  String _tipoVenta = 'contado';
  final DateTime _fechaVenta = DateTime.now();
  final _montoCtrl = TextEditingController();
  final _pagoInicialCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController();
  final _montoMensualCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _pagoInicialCtrl.dispose();
    _cuotasCtrl.dispose();
    _montoMensualCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cliente == null || _sistema == null) {
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
      await ref.read(sistemasRepositoryProvider).venderSistema(
            clienteId: _cliente!.id,
            sistemaId: _sistema!.id,
            fechaVenta: _fechaVenta,
            tipoVenta: _tipoVenta,
            montoTotal: montoTotal,
            pagoInicial: (esMensualidades || esSuscripcion) ? double.tryParse(_pagoInicialCtrl.text.trim()) : null,
            numeroCuotas: esMensualidades ? cuotas : null,
            montoMensual: esSuscripcion ? montoMensual : null,
          );
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
      title: const Text('VENDER SISTEMA'),
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
                data: (clientes) => DropdownButtonFormField<ClienteModel>(
                  initialValue: _cliente,
                  decoration: const InputDecoration(hintText: 'CLIENTE'),
                  dropdownColor: AppColors.superficieAlta,
                  items: clientes.map((c) => DropdownMenuItem(value: c, child: Text(c.nombreNegocio))).toList(),
                  onChanged: (v) => setState(() => _cliente = v),
                ),
              ),
              const SizedBox(height: 10),
              catalogoAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('NO SE PUDO CARGAR CATÁLOGO', style: TextStyle(color: AppColors.error)),
                data: (catalogo) => DropdownButtonFormField<SistemaModel>(
                  initialValue: _sistema,
                  decoration: const InputDecoration(hintText: 'SISTEMA'),
                  dropdownColor: AppColors.superficieAlta,
                  items: catalogo.map((s) => DropdownMenuItem(value: s, child: Text(s.nombre))).toList(),
                  onChanged: (v) => setState(() => _sistema = v),
                ),
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
              if (esSuscripcion) ...[
                const SizedBox(height: 8),
                const Text(
                  'EL PAGO INICIAL SE ASUME COBRADO AL FIRMAR. LA MENSUALIDAD SE VA SUMANDO SOLA CADA MES AL SALDO DEL CLIENTE.',
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
