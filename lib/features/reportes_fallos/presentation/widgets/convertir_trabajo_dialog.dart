import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/reporte_fallo_model.dart';
import '../../providers/reportes_fallos_provider.dart';

class ConvertirTrabajoDialog extends ConsumerStatefulWidget {
  final ReporteFalloModel reporte;
  const ConvertirTrabajoDialog({super.key, required this.reporte});

  @override
  ConsumerState<ConvertirTrabajoDialog> createState() => _ConvertirTrabajoDialogState();
}

class _ConvertirTrabajoDialogState extends ConsumerState<ConvertirTrabajoDialog> {
  final _montoCtrl = TextEditingController(text: '0');
  bool _esCredito = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(reportesFallosRepositoryProvider).convertirEnTrabajo(
            reporteId: widget.reporte.id,
            monto: monto,
            esCredito: monto > 0 && _esCredito,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'No se pudo convertir: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('CONVERTIR EN TRABAJO'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'MONTO A COBRAR (0 = GRATIS)'),
              autofocus: true,
            ),
            CheckboxListTile(
              value: _esCredito,
              onChanged: (v) => setState(() => _esCredito = v ?? false),
              title: const Text('ES A CRÉDITO', style: TextStyle(fontSize: 13)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        ElevatedButton(
          onPressed: _guardando ? null : _confirmar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('CONFIRMAR'),
        ),
      ],
    );
  }
}
