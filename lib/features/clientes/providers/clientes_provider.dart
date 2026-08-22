import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cliente_model.dart';
import '../data/clientes_repository.dart';

final clientesRepositoryProvider = Provider((ref) => ClientesRepository());

final clientesProvider = FutureProvider<List<ClienteModel>>((ref) {
  return ref.watch(clientesRepositoryProvider).listar();
});

final detalleClienteProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, clienteId) {
  return ref.watch(clientesRepositoryProvider).detalle(clienteId);
});
