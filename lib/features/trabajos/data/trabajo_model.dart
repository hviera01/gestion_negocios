class TrabajoModel {
  final String id;
  final String sistemaClienteId;
  final String descripcion;
  final DateTime fecha;
  final double monto;
  final bool esCredito;

  const TrabajoModel({
    required this.id,
    required this.sistemaClienteId,
    required this.descripcion,
    required this.fecha,
    required this.monto,
    required this.esCredito,
  });

  factory TrabajoModel.fromMap(Map<String, dynamic> map) => TrabajoModel(
        id: map['id'] as String,
        sistemaClienteId: map['sistema_cliente_id'] as String,
        descripcion: map['descripcion'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        monto: (map['monto'] as num).toDouble(),
        esCredito: map['es_credito'] as bool? ?? false,
      );
}
