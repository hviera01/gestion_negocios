import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../clientes/data/cliente_model.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../providers/creditos_provider.dart';

class CreditoManualFormDialog extends ConsumerStatefulWidget {
  const CreditoManualFormDialog({super.key});

  @override
  ConsumerState<CreditoManualFormDialog> createState() => _CreditoManualFormDialogState();
}

class _CreditoManualFormDialogState extends ConsumerState<CreditoManualFormDialog> {
  ClienteModel? _cliente;
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if (_cliente == null || monto == null) {
      setState(() => _error = 'Completá el cliente y el monto');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(creditosRepositoryProvider).crearManual(
            clienteId: _cliente!.id,
            montoTotal: monto,
            notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
            numeroCuotas: int.tryParse(_cuotasCtrl.text.trim()),
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

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('CRÉDITO MANUAL'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'MONTO *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cuotasCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'NÚMERO DE CUOTAS (OPCIONAL)'),
            ),
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
