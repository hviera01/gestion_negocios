import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trabajo_model.dart';
import '../data/trabajos_repository.dart';

final trabajosRepositoryProvider = Provider((ref) => TrabajosRepository());

final trabajosProvider = FutureProvider<List<TrabajoModel>>((ref) {
  return ref.watch(trabajosRepositoryProvider).listar();
});
