import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../providers/sistemas_provider.dart';

class NuevoSistemaDialog extends ConsumerStatefulWidget {
  const NuevoSistemaDialog({super.key});

  @override
  ConsumerState<NuevoSistemaDialog> createState() => _NuevoSistemaDialogState();
}

class _NuevoSistemaDialogState extends ConsumerState<NuevoSistemaDialog> {
  final _nombreCtrl = TextEditingController();
  final _githubOwnerCtrl = TextEditingController();
  final _githubRepoCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _githubOwnerCtrl.dispose();
    _githubRepoCtrl.dispose();
    super.dispose();
  }

  String _slugDesdeNombre(String nombre) {
    final normalizado = nombre
        .toLowerCase()
        .replaceAll(RegExp('[áàä]'), 'a')
        .replaceAll(RegExp('[éèë]'), 'e')
        .replaceAll(RegExp('[íìï]'), 'i')
        .replaceAll(RegExp('[óòö]'), 'o')
        .replaceAll(RegExp('[úùü]'), 'u')
        .replaceAll('ñ', 'n');
    return normalizado.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(sistemasRepositoryProvider).crearSistema(
            nombre: _nombreCtrl.text.trim(),
            slug: _slugDesdeNombre(_nombreCtrl.text.trim()),
            githubOwner: _githubOwnerCtrl.text.trim().isEmpty ? null : _githubOwnerCtrl.text.trim(),
            githubRepo: _githubRepoCtrl.text.trim().isEmpty ? null : _githubRepoCtrl.text.trim(),
          );
      ref.invalidate(catalogoSistemasProvider);
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
      title: const Text('NUEVO SISTEMA EN EL CATÁLOGO'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [MayusculasFormatter()],
              decoration: const InputDecoration(hintText: 'NOMBRE DEL SISTEMA *'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _githubOwnerCtrl, decoration: const InputDecoration(hintText: 'USUARIO DE GITHUB (OPCIONAL)')),
            const SizedBox(height: 10),
            TextField(controller: _githubRepoCtrl, decoration: const InputDecoration(hintText: 'REPOSITORIO DE GITHUB (OPCIONAL)')),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'EL DE GITHUB ES SOLO PARA MOSTRAR LA VERSIÓN PUBLICADA — SI NO LO TIENE TODAVÍA, DEJALO VACÍO.',
                style: TextStyle(color: AppColors.textoTerciario, fontSize: 11),
              ),
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
