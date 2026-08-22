import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sistema_model.dart';
import '../../../core/services/version_sistema_service.dart';
import '../data/sistema_cliente_model.dart';
import '../data/sistemas_repository.dart';

final sistemasRepositoryProvider = Provider((ref) => SistemasRepository());

final catalogoSistemasProvider = FutureProvider<List<SistemaModel>>((ref) {
  return ref.watch(sistemasRepositoryProvider).listarCatalogo();
});

final sistemasClienteProvider = FutureProvider.family<List<SistemaClienteModel>, String?>((ref, clienteId) {
  return ref.watch(sistemasRepositoryProvider).listarVendidos(clienteId: clienteId);
});

final versionSistemaProvider = FutureProvider.family<String?, SistemaModel>((ref, sistema) {
  return VersionSistemaService.obtenerVersion(sistema);
});
