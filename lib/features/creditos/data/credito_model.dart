class CreditoModel {
  final String id;
  final String clienteId;
  final String origen;
  final String? sistemaClienteId;
  final String? trabajoId;
  final double montoTotal;
  final double saldoPendiente;
  final DateTime fechaRegistro;
  final DateTime? fechaVencimiento;
  final String? notas;

  const CreditoModel({
    required this.id,
    required this.clienteId,
    required this.origen,
    this.sistemaClienteId,
    this.trabajoId,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.fechaRegistro,
    this.fechaVencimiento,
    this.notas,
  });

  bool get liquidado => saldoPendiente <= 0;
  bool get vencido => fechaVencimiento != null && !liquidado && fechaVencimiento!.isBefore(DateTime.now());

  factory CreditoModel.fromMap(Map<String, dynamic> map) => CreditoModel(
        id: map['id'] as String,
        clienteId: map['cliente_id'] as String,
        origen: map['origen'] as String,
        sistemaClienteId: map['sistema_cliente_id'] as String?,
        trabajoId: map['trabajo_id'] as String?,
        montoTotal: (map['monto_total'] as num).toDouble(),
        saldoPendiente: (map['saldo_pendiente'] as num).toDouble(),
        fechaRegistro: DateTime.parse(map['fecha_registro'] as String),
        fechaVencimiento: map['fecha_vencimiento'] != null ? DateTime.parse(map['fecha_vencimiento'] as String) : null,
        notas: map['notas'] as String?,
      );
}

class CuotaModel {
  final String id;
  final String creditoId;
  final int numero;
  final DateTime fechaVencimiento;
  final double monto;
  final bool pagada;

  const CuotaModel({
    required this.id,
    required this.creditoId,
    required this.numero,
    required this.fechaVencimiento,
    required this.monto,
    required this.pagada,
  });

  factory CuotaModel.fromMap(Map<String, dynamic> map) => CuotaModel(
        id: map['id'] as String,
        creditoId: map['credito_id'] as String,
        numero: map['numero'] as int,
        fechaVencimiento: DateTime.parse(map['fecha_vencimiento'] as String),
        monto: (map['monto'] as num).toDouble(),
        pagada: map['pagada'] as bool? ?? false,
      );
}

class AbonoModel {
  final String id;
  final String creditoId;
  final DateTime fecha;
  final double montoAbonado;
  final double saldoAnterior;
  final double interes;
  final double saldoPendiente;
  final String? metodoPago;
  final String? numeroRecibo;

  const AbonoModel({
    required this.id,
    required this.creditoId,
    required this.fecha,
    required this.montoAbonado,
    required this.saldoAnterior,
    required this.interes,
    required this.saldoPendiente,
    this.metodoPago,
    this.numeroRecibo,
  });

  factory AbonoModel.fromMap(Map<String, dynamic> map) => AbonoModel(
        id: map['id'] as String,
        creditoId: map['credito_id'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        montoAbonado: (map['monto_abonado'] as num).toDouble(),
        saldoAnterior: (map['saldo_anterior'] as num).toDouble(),
        interes: (map['interes'] as num).toDouble(),
        saldoPendiente: (map['saldo_pendiente'] as num).toDouble(),
        metodoPago: map['metodo_pago'] as String?,
        numeroRecibo: map['numero_recibo'] as String?,
      );
}
