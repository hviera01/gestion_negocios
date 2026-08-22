class SistemaModel {
  final String id;
  final String nombre;
  final String slug;
  final String githubOwner;
  final String githubRepo;
  final bool activo;

  const SistemaModel({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.githubOwner,
    required this.githubRepo,
    required this.activo,
  });

  factory SistemaModel.fromMap(Map<String, dynamic> map) => SistemaModel(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        slug: map['slug'] as String,
        githubOwner: map['github_owner'] as String,
        githubRepo: map['github_repo'] as String,
        activo: map['activo'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is SistemaModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
