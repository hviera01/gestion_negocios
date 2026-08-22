class ReporteFalloModel {
  final String id;
  final String clienteId;
  final String? sistemaClienteId;
  final String descripcion;
  final DateTime fechaReporte;
  final String estado;
  final bool cobrado;
  final double? montoCobrado;

  const ReporteFalloModel({
    required this.id,
    required this.clienteId,
    this.sistemaClienteId,
    required this.descripcion,
    required this.fechaReporte,
    required this.estado,
    required this.cobrado,
    this.montoCobrado,
  });

  factory ReporteFalloModel.fromMap(Map<String, dynamic> map) => ReporteFalloModel(
        id: map['id'] as String,
        clienteId: map['cliente_id'] as String,
        sistemaClienteId: map['sistema_cliente_id'] as String?,
        descripcion: map['descripcion'] as String,
        fechaReporte: DateTime.parse(map['fecha_reporte'] as String),
        estado: map['estado'] as String,
        cobrado: map['cobrado'] as bool? ?? false,
        montoCobrado: (map['monto_cobrado'] as num?)?.toDouble(),
      );
}
