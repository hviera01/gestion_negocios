class SistemaClienteModel {
  final String id;
  final String clienteId;
  final String sistemaId;
  final String sistemaNombre;
  final String sistemaSlug;
  final DateTime fechaVenta;
  final String tipoVenta;
  final double montoTotal;
  final double? pagoInicial;
  final int? numeroCuotas;
  final bool activo;

  const SistemaClienteModel({
    required this.id,
    required this.clienteId,
    required this.sistemaId,
    required this.sistemaNombre,
    required this.sistemaSlug,
    required this.fechaVenta,
    required this.tipoVenta,
    required this.montoTotal,
    this.pagoInicial,
    this.numeroCuotas,
    required this.activo,
  });

  factory SistemaClienteModel.fromMap(Map<String, dynamic> map) => SistemaClienteModel(
        id: map['id'] as String,
        clienteId: map['cliente_id'] as String,
        sistemaId: map['sistema_id'] as String,
        sistemaNombre: map['sistema_nombre'] as String,
        sistemaSlug: map['sistema_slug'] as String,
        fechaVenta: DateTime.parse(map['fecha_venta'] as String),
        tipoVenta: map['tipo_venta'] as String,
        montoTotal: (map['monto_total'] as num).toDouble(),
        pagoInicial: (map['pago_inicial'] as num?)?.toDouble(),
        numeroCuotas: map['numero_cuotas'] as int?,
        activo: map['activo'] as bool? ?? true,
      );
}
