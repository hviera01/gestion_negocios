import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../sistemas/data/sistema_cliente_model.dart';
import '../../../sistemas/providers/sistemas_provider.dart';
import '../../providers/trabajos_provider.dart';

class TrabajoFormDialog extends ConsumerStatefulWidget {
  const TrabajoFormDialog({super.key});

  @override
  ConsumerState<TrabajoFormDialog> createState() => _TrabajoFormDialogState();
}

class _TrabajoFormDialogState extends ConsumerState<TrabajoFormDialog> {
  SistemaClienteModel? _sistemaCliente;
  final _descripcionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController(text: '0');
  bool _esCredito = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    if (_sistemaCliente == null || _descripcionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completá el sistema y la descripción');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(trabajosRepositoryProvider).crear(
            sistemaClienteId: _sistemaCliente!.id,
            descripcion: _descripcionCtrl.text.trim(),
            fecha: DateTime.now(),
            monto: monto,
            esCredito: monto > 0 && _esCredito,
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
    final sistemasAsync = ref.watch(sistemasClienteProvider(null));
    final clientesAsync = ref.watch(clientesProvider);

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('NUEVO TRABAJO'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sistemasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('NO SE PUDO CARGAR SISTEMAS', style: TextStyle(color: AppColors.error)),
                data: (sistemas) {
                  final nombresClientes = clientesAsync.value ?? [];
                  return DropdownButtonFormField<SistemaClienteModel>(
                    initialValue: _sistemaCliente,
                    isExpanded: true,
                    decoration: const InputDecoration(hintText: 'SISTEMA DEL CLIENTE'),
                    dropdownColor: AppColors.superficieAlta,
                    items: sistemas.map((sc) {
                      final cliente = nombresClientes.where((c) => c.id == sc.clienteId);
                      final nombreCliente = cliente.isEmpty ? '' : cliente.first.nombreNegocio;
                      return DropdownMenuItem(
                        value: sc,
                        child: Text('$nombreCliente · ${sc.sistemaNombre}', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _sistemaCliente = v),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descripcionCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [MayusculasFormatter()],
                decoration: const InputDecoration(hintText: 'DESCRIPCIÓN DEL TRABAJO *'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'MONTO COBRADO (0 = GRATIS)'),
              ),
              CheckboxListTile(
                value: _esCredito,
                onChanged: (v) => setState(() => _esCredito = v ?? false),
                title: const Text('ES A CRÉDITO', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
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
