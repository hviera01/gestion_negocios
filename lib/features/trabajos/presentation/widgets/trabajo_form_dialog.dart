import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../sistemas/data/sistema_cliente_model.dart';
import '../../../sistemas/providers/sistemas_provider.dart';
import '../../data/trabajo_model.dart';
import '../../providers/trabajos_provider.dart';

final _fechaFmt = DateFormat('dd/MM/yyyy');

class TrabajoFormDialog extends ConsumerStatefulWidget {
  final TrabajoModel? existente;
  const TrabajoFormDialog({super.key, this.existente});

  @override
  ConsumerState<TrabajoFormDialog> createState() => _TrabajoFormDialogState();
}

class _TrabajoFormDialogState extends ConsumerState<TrabajoFormDialog> {
  SistemaClienteModel? _sistemaCliente;
  final _descripcionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController(text: '0');
  bool _esCredito = false;
  late DateTime _fecha;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _fecha = e?.fecha ?? DateTime.now();
    if (e != null) {
      _descripcionCtrl.text = e.descripcion;
      _montoCtrl.text = e.monto.toStringAsFixed(2);
      _esCredito = e.esCredito;
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    if (_descripcionCtrl.text.trim().isEmpty || (!_editando && _sistemaCliente == null)) {
      setState(() => _error = 'Completá el sistema y la descripción');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(trabajosRepositoryProvider);
      if (_editando) {
        await repo.actualizar(
          id: widget.existente!.id,
          descripcion: _descripcionCtrl.text.trim(),
          fecha: _fecha,
          monto: monto,
        );
      } else {
        await repo.crear(
          sistemaClienteId: _sistemaCliente!.id,
          descripcion: _descripcionCtrl.text.trim(),
          fecha: _fecha,
          monto: monto,
          esCredito: monto > 0 && _esCredito,
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
    final sistemasAsync = ref.watch(sistemasClienteProvider(null));
    final clientesAsync = ref.watch(clientesProvider);

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_editando ? 'EDITAR TRABAJO' : 'NUEVO TRABAJO'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_editando)
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
              if (!_editando) const SizedBox(height: 10),
              TextField(
                controller: _descripcionCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [MayusculasFormatter()],
                decoration: const InputDecoration(hintText: 'DESCRIPCIÓN DEL TRABAJO *'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(hintText: 'FECHA', suffixIcon: Icon(Icons.calendar_today_rounded, size: 16)),
                  child: Text(_fechaFmt.format(_fecha)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'MONTO COBRADO (0 = GRATIS)'),
              ),
              if (!_editando)
                CheckboxListTile(
                  value: _esCredito,
                  onChanged: (v) => setState(() => _esCredito = v ?? false),
                  title: const Text('ES A CRÉDITO', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                )
              else if (widget.existente!.esCredito) ...[
                const SizedBox(height: 8),
                const Text(
                  'ESTE TRABAJO QUEDÓ REGISTRADO A CRÉDITO — SI CAMBIÁS EL MONTO ACÁ Y TODAVÍA NO TIENE ABONOS, EL SALDO SE AJUSTA SOLO.',
                  style: TextStyle(color: AppColors.textoTerciario, fontSize: 11),
                ),
              ],
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
