import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cobro_model.dart';
import '../data/cobros_repository.dart';

final cobrosRepositoryProvider = Provider((ref) => CobrosRepository());

final cobrosProvider = FutureProvider<List<CobroModel>>((ref) {
  return ref.watch(cobrosRepositoryProvider).listar();
});
