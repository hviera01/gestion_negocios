class ClienteModel {
  final String id;
  final String nombreNegocio;
  final String? nombreContacto;
  final String? telefono;
  final String? email;
  final String? notas;

  const ClienteModel({
    required this.id,
    required this.nombreNegocio,
    this.nombreContacto,
    this.telefono,
    this.email,
    this.notas,
  });

  factory ClienteModel.fromMap(Map<String, dynamic> map) => ClienteModel(
        id: map['id'] as String,
        nombreNegocio: map['nombre_negocio'] as String,
        nombreContacto: map['nombre_contacto'] as String?,
        telefono: map['telefono'] as String?,
        email: map['email'] as String?,
        notas: map['notas'] as String?,
      );
}
