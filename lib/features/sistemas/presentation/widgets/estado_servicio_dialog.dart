import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../data/sistema_cliente_model.dart';
import '../../providers/sistemas_provider.dart';

Color colorEstadoServicio(String estado) {
  switch (estado) {
    case 'bloqueado':
      return AppColors.error;
    case 'aviso':
      return AppColors.advertencia;
    default:
      return AppColors.exito;
  }
}

class EstadoServicioDialog extends ConsumerStatefulWidget {
  final SistemaClienteModel venta;
  const EstadoServicioDialog({super.key, required this.venta});

  @override
  ConsumerState<EstadoServicioDialog> createState() => _EstadoServicioDialogState();
}

class _EstadoServicioDialogState extends ConsumerState<EstadoServicioDialog> {
  late String _estado;
  late final TextEditingController _mensajeCtrl;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _estado = widget.venta.estadoServicio;
    _mensajeCtrl = TextEditingController(text: widget.venta.mensajeServicio ?? '');
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(sistemasRepositoryProvider).cambiarEstadoServicio(
            id: widget.venta.id,
            estado: _estado,
            mensaje: _mensajeCtrl.text,
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
    final v = widget.venta;
    final codigo = v.codigoAcceso;
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('${(v.clienteNombre ?? v.sistemaNombre).toUpperCase()} · ${v.sistemaNombre.toUpperCase()}', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ESTADO DEL SISTEMA DEL CLIENTE', style: TextStyle(color: AppColors.textoTerciario, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              RadioGroup<String>(
                groupValue: _estado,
                onChanged: (x) => setState(() => _estado = x!),
                child: Column(
                  children: [
                    for (final o in const [
                      ('activo', 'ACTIVO', 'FUNCIONA NORMAL'),
                      ('aviso', 'AVISO', 'FUNCIONA, PERO MUESTRA EL MENSAJE AL ABRIR'),
                      ('bloqueado', 'BLOQUEADO', 'NO DEJA USAR EL SISTEMA HASTA REACTIVARLO'),
                    ])
                      RadioListTile<String>(
                        value: o.$1,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: colorEstadoServicio(o.$1),
                        title: Text(o.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(o.$3, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                      ),
                  ],
                ),
              ),
              if (_estado != 'activo') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _mensajeCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [MayusculasFormatter()],
                  decoration: const InputDecoration(hintText: 'MENSAJE PARA EL CLIENTE (OPCIONAL)'),
                ),
              ],
              if (codigo != null) ...[
                const SizedBox(height: 16),
                const Text('CÓDIGO DE ESTE SISTEMA', style: TextStyle(color: AppColors.textoTerciario, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: SelectableText(codigo, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copiar',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: codigo));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
                        }
                      },
                    ),
                  ],
                ),
                const Text(
                  'ES EL CÓDIGO QUE EL SISTEMA DEL CLIENTE USA PARA CONSULTAR SU ESTADO.',
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
