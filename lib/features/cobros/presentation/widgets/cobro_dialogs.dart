import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mayusculas_formatter.dart';
import '../../../../core/utils/monto_formatter.dart';
import '../../data/cobro_model.dart';
import '../../providers/cobros_provider.dart';

final _fecha = DateFormat('dd/MM/yyyy');

class RegistrarPagoCobroDialog extends ConsumerStatefulWidget {
  final CobroModel cobro;
  const RegistrarPagoCobroDialog({super.key, required this.cobro});

  @override
  ConsumerState<RegistrarPagoCobroDialog> createState() => _RegistrarPagoCobroDialogState();
}

class _RegistrarPagoCobroDialogState extends ConsumerState<RegistrarPagoCobroDialog> {
  late final TextEditingController _montoCtrl;
  late final FocusNode _montoFoco;
  final _reciboCtrl = TextEditingController();
  String? _metodoPago;
  DateTime _fechaPago = DateTime.now();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(text: textoMonto(widget.cobro.monto));
    _montoFoco = focoMonto(_montoCtrl);
  }

  Future<void> _elegirFechaPago() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fechaPago = elegida);
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _montoFoco.dispose();
    _reciboCtrl.dispose();
    super.dispose();
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
      await ref.read(cobrosRepositoryProvider).registrarPago(
            widget.cobro,
            monto: monto,
            metodoPago: _metodoPago,
            numeroRecibo: _reciboCtrl.text.trim().isEmpty ? null : _reciboCtrl.text.trim(),
            fecha: _fechaPago,
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
    final c = widget.cobro;
    final detalle = c.esSuscripcion
        ? 'MENSUALIDAD DEL ${_fecha.format(c.fechaVencimiento)}'
        : 'CUOTA ${c.numeroCuota}/${c.totalCuotas} · ${_fecha.format(c.fechaVencimiento)}';

    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(c.clienteNombre.toUpperCase()),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detalle, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: _montoCtrl,
              focusNode: _montoFoco,
              keyboardType: TextInputType.number,
              inputFormatters: [MontoFormatter()],
              decoration: const InputDecoration(hintText: 'MONTO COBRADO *'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _elegirFechaPago,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'FECHA DEL PAGO',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                ),
                child: Text(_fecha.format(_fechaPago)),
              ),
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
            if (c.esSuscripcion) ...[
              const SizedBox(height: 10),
              const Text(
                'AL REGISTRAR EL PAGO, EL PRÓXIMO COBRO PASA AL MES SIGUIENTE.',
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
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('MARCAR PAGADO'),
        ),
      ],
    );
  }
}

class CambiarFechaCobroDialog extends ConsumerStatefulWidget {
  final CobroModel cobro;
  const CambiarFechaCobroDialog({super.key, required this.cobro});

  @override
  ConsumerState<CambiarFechaCobroDialog> createState() => _CambiarFechaCobroDialogState();
}

class _CambiarFechaCobroDialogState extends ConsumerState<CambiarFechaCobroDialog> {
  late DateTime _nueva;
  bool _moverSiguientes = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nueva = widget.cobro.fechaVencimiento;
  }

  Future<void> _elegir() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _nueva,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _nueva = elegida);
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(cobrosRepositoryProvider).cambiarFecha(widget.cobro, _nueva, moverSiguientes: _moverSiguientes);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'No se pudo cambiar la fecha: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cobro;
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('FECHA DE COBRO · ${c.clienteNombre.toUpperCase()}', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _elegir,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'NUEVA FECHA',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                ),
                child: Text(_fecha.format(_nueva)),
              ),
            ),
            const SizedBox(height: 10),
            if (!c.esSuscripcion)
              CheckboxListTile(
                value: _moverSiguientes,
                onChanged: (v) => setState(() => _moverSiguientes = v ?? true),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('MOVER TAMBIÉN LAS CUOTAS SIGUIENTES', style: TextStyle(fontSize: 12)),
              )
            else
              const Text(
                'LOS COBROS SIGUIENTES SE CALCULAN MES A MES DESDE ESTA FECHA.',
                style: TextStyle(color: AppColors.textoTerciario, fontSize: 11),
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
