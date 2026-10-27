enum EstadoCobro { vencido, hoy, proximo, lejano }

class CobroModel {
  final String tipo;
  final String referenciaId;
  final String creditoId;
  final String clienteId;
  final String clienteNombre;
  final String concepto;
  final double monto;
  final DateTime fechaVencimiento;
  final int? numeroCuota;
  final int? totalCuotas;
  final double saldoPendiente;

  const CobroModel({
    required this.tipo,
    required this.referenciaId,
    required this.creditoId,
    required this.clienteId,
    required this.clienteNombre,
    required this.concepto,
    required this.monto,
    required this.fechaVencimiento,
    this.numeroCuota,
    this.totalCuotas,
    required this.saldoPendiente,
  });

  bool get esSuscripcion => tipo == 'suscripcion';

  int get diasParaVencer {
    final hoy = DateTime.now();
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final f = DateTime(fechaVencimiento.year, fechaVencimiento.month, fechaVencimiento.day);
    return f.difference(h).inDays;
  }

  EstadoCobro get estado {
    final d = diasParaVencer;
    if (d < 0) return EstadoCobro.vencido;
    if (d == 0) return EstadoCobro.hoy;
    if (d <= 7) return EstadoCobro.proximo;
    return EstadoCobro.lejano;
  }

  factory CobroModel.fromMap(Map<String, dynamic> map) => CobroModel(
        tipo: map['tipo'] as String,
        referenciaId: map['referencia_id'] as String,
        creditoId: map['credito_id'] as String,
        clienteId: map['cliente_id'] as String,
        clienteNombre: map['cliente_nombre'] as String,
        concepto: map['concepto'] as String,
        monto: (map['monto'] as num).toDouble(),
        fechaVencimiento: DateTime.parse(map['fecha_vencimiento'] as String),
        numeroCuota: map['numero_cuota'] as int?,
        totalCuotas: map['total_cuotas'] as int?,
        saldoPendiente: (map['saldo_pendiente'] as num).toDouble(),
      );
}
