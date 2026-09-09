import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../clientes/data/cliente_model.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../data/credito_model.dart';
import '../../providers/creditos_provider.dart';

final _fechaFmt = DateFormat('dd/MM/yyyy');

class CreditoManualFormDialog extends ConsumerStatefulWidget {
  final CreditoModel? existente;
  const CreditoManualFormDialog({super.key, this.existente});

  @override
  ConsumerState<CreditoManualFormDialog> createState() => _CreditoManualFormDialogState();
}

class _CreditoManualFormDialogState extends ConsumerState<CreditoManualFormDialog> {
  ClienteModel? _cliente;
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController();
  DateTime? _fechaVencimiento;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    if (e != null) {
      _montoCtrl.text = e.montoTotal.toStringAsFixed(2);
      _notasCtrl.text = e.notas ?? '';
      _fechaVencimiento = e.fechaVencimiento;
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fechaVencimiento = elegida);
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if ((!_editando && _cliente == null) || monto == null) {
      setState(() => _error = 'Completá el cliente y el monto');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(creditosRepositoryProvider);
      if (_editando) {
        await repo.actualizarManual(
          id: widget.existente!.id,
          montoTotal: monto,
          fechaVencimiento: _fechaVencimiento,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
      } else {
        await repo.crearManual(
          clienteId: _cliente!.id,
          montoTotal: monto,
          fechaVencimiento: _fechaVencimiento,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
          numeroCuotas: int.tryParse(_cuotasCtrl.text.trim()),
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

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_editando ? 'EDITAR CRÉDITO' : 'CRÉDITO MANUAL'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_editando)
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
            if (!_editando) const SizedBox(height: 10),
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'MONTO *'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _elegirFecha,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: 'FECHA DE VENCIMIENTO (OPCIONAL)',
                  suffixIcon: _fechaVencimiento != null
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _fechaVencimiento = null))
                      : const Icon(Icons.calendar_today_rounded, size: 16),
                ),
                child: Text(
                  _fechaVencimiento != null ? _fechaFmt.format(_fechaVencimiento!) : 'SIN ELEGIR',
                  style: TextStyle(color: _fechaVencimiento != null ? AppColors.textoPrimario : AppColors.textoTerciario),
                ),
              ),
            ),
            if (!_editando) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _cuotasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'NÚMERO DE CUOTAS (OPCIONAL)'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _notasCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [MayusculasFormatter()],
              decoration: const InputDecoration(hintText: 'NOTAS'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
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
