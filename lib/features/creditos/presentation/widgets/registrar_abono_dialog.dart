import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../data/credito_model.dart';
import '../../providers/creditos_provider.dart';

final _moneda = NumberFormat.currency(locale: 'en_US', symbol: 'L.');

class RegistrarAbonoDialog extends ConsumerStatefulWidget {
  final CreditoModel credito;
  const RegistrarAbonoDialog({super.key, required this.credito});

  @override
  ConsumerState<RegistrarAbonoDialog> createState() => _RegistrarAbonoDialogState();
}

class _RegistrarAbonoDialogState extends ConsumerState<RegistrarAbonoDialog> {
  final _montoCtrl = TextEditingController();
  final _interesCtrl = TextEditingController(text: '0');
  final _reciboCtrl = TextEditingController();
  String? _metodoPago;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _interesCtrl.dispose();
    _reciboCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresá un monto válido');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(creditosRepositoryProvider).registrarAbono(
            creditoId: widget.credito.id,
            montoAbonado: monto,
            interes: double.tryParse(_interesCtrl.text.trim()) ?? 0,
            metodoPago: _metodoPago,
            numeroRecibo: _reciboCtrl.text.trim().isEmpty ? null : _reciboCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'No se pudo registrar: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('SALDO ACTUAL: ${_moneda.format(widget.credito.saldoPendiente)}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'MONTO A ABONAR *'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _interesCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              : const Text('REGISTRAR'),
        ),
      ],
    );
  }
}
