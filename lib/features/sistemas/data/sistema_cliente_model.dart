class SistemaClienteModel {
  final String id;
  final String clienteId;
  final String sistemaId;
  final String sistemaNombre;
  final String sistemaSlug;
  final DateTime fechaVenta;
  final String tipoVenta;
  final double? montoTotal;
  final double? pagoInicial;
  final int? numeroCuotas;
  final double? montoMensual;
  final DateTime? fechaPrimerPago;
  final bool activo;
  final String estadoServicio;
  final String? mensajeServicio;
  final String? codigoAcceso;
  final String? clienteNombre;

  const SistemaClienteModel({
    required this.id,
    required this.clienteId,
    required this.sistemaId,
    required this.sistemaNombre,
    required this.sistemaSlug,
    required this.fechaVenta,
    required this.tipoVenta,
    this.montoTotal,
    this.pagoInicial,
    this.numeroCuotas,
    this.montoMensual,
    this.fechaPrimerPago,
    required this.activo,
    this.estadoServicio = 'activo',
    this.mensajeServicio,
    this.codigoAcceso,
    this.clienteNombre,
  });

  factory SistemaClienteModel.fromMap(Map<String, dynamic> map) => SistemaClienteModel(
        id: map['id'] as String,
        clienteId: map['cliente_id'] as String,
        sistemaId: map['sistema_id'] as String,
        sistemaNombre: map['sistema_nombre'] as String,
        sistemaSlug: map['sistema_slug'] as String,
        fechaVenta: DateTime.parse(map['fecha_venta'] as String),
        tipoVenta: map['tipo_venta'] as String,
        montoTotal: (map['monto_total'] as num?)?.toDouble(),
        pagoInicial: (map['pago_inicial'] as num?)?.toDouble(),
        numeroCuotas: map['numero_cuotas'] as int?,
        montoMensual: (map['monto_mensual'] as num?)?.toDouble(),
        fechaPrimerPago: map['fecha_primer_pago'] != null ? DateTime.parse(map['fecha_primer_pago'] as String) : null,
        activo: map['activo'] as bool? ?? true,
        estadoServicio: map['estado_servicio'] as String? ?? 'activo',
        mensajeServicio: map['mensaje_servicio'] as String?,
        codigoAcceso: map['codigo_acceso'] as String?,
        clienteNombre: map['cliente_nombre'] as String?,
      );
}
