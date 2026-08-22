import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credito_model.dart';
import '../data/creditos_repository.dart';

final creditosRepositoryProvider = Provider((ref) => CreditosRepository());

final creditosProvider = FutureProvider<List<CreditoModel>>((ref) {
  return ref.watch(creditosRepositoryProvider).listar();
});

final cuotasCreditoProvider = FutureProvider.family<List<CuotaModel>, String>((ref, creditoId) {
  return ref.watch(creditosRepositoryProvider).listarCuotas(creditoId);
});

final abonosCreditoProvider = FutureProvider.family<List<AbonoModel>, String>((ref, creditoId) {
  return ref.watch(creditosRepositoryProvider).listarAbonos(creditoId);
});
