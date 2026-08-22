import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../clientes/data/cliente_model.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../sistemas/data/sistema_cliente_model.dart';
import '../../../sistemas/providers/sistemas_provider.dart';
import '../../providers/reportes_fallos_provider.dart';

class ReporteFalloFormDialog extends ConsumerStatefulWidget {
  const ReporteFalloFormDialog({super.key});

  @override
  ConsumerState<ReporteFalloFormDialog> createState() => _ReporteFalloFormDialogState();
}

class _ReporteFalloFormDialogState extends ConsumerState<ReporteFalloFormDialog> {
  ClienteModel? _cliente;
  SistemaClienteModel? _sistemaCliente;
  final _descripcionCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cliente == null || _descripcionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completá el cliente y la descripción');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(reportesFallosRepositoryProvider).crear(
            clienteId: _cliente!.id,
            sistemaClienteId: _sistemaCliente?.id,
            descripcion: _descripcionCtrl.text.trim(),
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
    final sistemasAsync = _cliente == null ? null : ref.watch(sistemasClienteProvider(_cliente!.id));

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('NUEVO REPORTE DE FALLO'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
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
                  onChanged: (v) => setState(() {
                    _cliente = v;
                    _sistemaCliente = null;
                  }),
                ),
              ),
              if (sistemasAsync != null) ...[
                const SizedBox(height: 10),
                sistemasAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (sistemas) => sistemas.isEmpty
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<SistemaClienteModel>(
                          initialValue: _sistemaCliente,
                          decoration: const InputDecoration(hintText: 'SISTEMA (OPCIONAL)'),
                          dropdownColor: AppColors.superficieAlta,
                          items: sistemas.map((s) => DropdownMenuItem(value: s, child: Text(s.sistemaNombre))).toList(),
                          onChanged: (v) => setState(() => _sistemaCliente = v),
                        ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _descripcionCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [MayusculasFormatter()],
                decoration: const InputDecoration(hintText: 'DESCRIPCIÓN DEL FALLO *'),
                maxLines: 3,
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
