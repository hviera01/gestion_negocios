import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../providers/clientes_provider.dart';

class ClienteFormDialog extends ConsumerStatefulWidget {
  const ClienteFormDialog({super.key});

  @override
  ConsumerState<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends ConsumerState<ClienteFormDialog> {
  final _nombreCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contactoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El nombre del negocio es obligatorio');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(clientesRepositoryProvider).crear(
            nombreNegocio: _nombreCtrl.text.trim(),
            nombreContacto: _contactoCtrl.text.trim().isEmpty ? null : _contactoCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
            email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
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
      title: const Text('NUEVO CLIENTE'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [MayusculasFormatter()],
              decoration: const InputDecoration(hintText: 'NOMBRE DEL NEGOCIO *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contactoCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [MayusculasFormatter()],
              decoration: const InputDecoration(hintText: 'NOMBRE DE CONTACTO'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _telefonoCtrl, decoration: const InputDecoration(hintText: 'TELÉFONO')),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [MayusculasFormatter()],
              decoration: const InputDecoration(hintText: 'EMAIL'),
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
