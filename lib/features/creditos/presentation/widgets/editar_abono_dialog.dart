import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../../core/utils/monto_formatter.dart';
import '../../data/credito_model.dart';
import '../../providers/creditos_provider.dart';

final _fechaFmt = DateFormat('dd/MM/yyyy');

class EditarAbonoDialog extends ConsumerStatefulWidget {
  final AbonoModel abono;
  const EditarAbonoDialog({super.key, required this.abono});

  @override
  ConsumerState<EditarAbonoDialog> createState() => _EditarAbonoDialogState();
}

class _EditarAbonoDialogState extends ConsumerState<EditarAbonoDialog> {
  late final TextEditingController _montoCtrl;
  late final TextEditingController _interesCtrl;
  late final TextEditingController _reciboCtrl;
  late DateTime _fecha;
  String? _metodoPago;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.abono;
    _montoCtrl = TextEditingController(text: textoMonto(a.montoAbonado));
    _interesCtrl = TextEditingController(text: textoMonto(a.interes));
    _reciboCtrl = TextEditingController(text: a.numeroRecibo ?? '');
    _fecha = a.fecha.toLocal();
    const validos = ['efectivo', 'transferencia', 'tarjeta'];
    _metodoPago = validos.contains(a.metodoPago) ? a.metodoPago : null;
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _interesCtrl.dispose();
    _reciboCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) {
      setState(() => _fecha = DateTime(elegida.year, elegida.month, elegida.day, _fecha.hour, _fecha.minute));
    }
  }

  Future<void> _guardar() async {
    final monto = parsearMonto(_montoCtrl.text);
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresá un monto válido');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(creditosRepositoryProvider).editarAbono(
            abonoId: widget.abono.id,
            fecha: _fecha,
            montoAbonado: monto,
            interes: parsearMonto(_interesCtrl.text) ?? 0,
            metodoPago: _metodoPago,
            numeroRecibo: _reciboCtrl.text.trim().isEmpty ? null : _reciboCtrl.text.trim(),
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
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('EDITAR PAGO'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MontoFormatter()],
                decoration: const InputDecoration(hintText: 'MONTO *'),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    hintText: 'FECHA DEL PAGO',
                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                  ),
                  child: Text(_fechaFmt.format(_fecha)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _interesCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MontoFormatter()],
                decoration: const InputDecoration(hintText: 'INTERÉS (OPCIONAL)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _metodoPago,
                decoration: const InputDecoration(hintText: 'MÉTODO DE PAGO'),
                dropdownColor: AppColors.superficieAlta,
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('EFECTIVO')),
                  DropdownMenuItem(value: 'transferencia', child: Text('TRANSFERENCIA')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('TARJETA')),
                ],
                onChanged: (v) => setState(() => _metodoPago = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reciboCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [MayusculasFormatter()],
                decoration: const InputDecoration(hintText: 'N° DE RECIBO (OPCIONAL)'),
              ),
              const SizedBox(height: 10),
              const Text(
                'EL SALDO DEL CRÉDITO Y LAS CUOTAS PAGADAS SE RECALCULAN CON EL NUEVO MONTO.',
                style: TextStyle(color: AppColors.textoTerciario, fontSize: 11),
              ),
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
