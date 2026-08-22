import '../../../core/data/rpc_client.dart';
import 'trabajo_model.dart';

class TrabajosRepository {
  Future<List<TrabajoModel>> listar({String? sistemaClienteId}) async {
    final res = await RpcClient.call('listar_trabajos', {'p_sistema_cliente_id': sistemaClienteId});
    return (res as List).map((e) => TrabajoModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> crear({
    required String sistemaClienteId,
    required String descripcion,
    required DateTime fecha,
    double monto = 0,
    bool esCredito = false,
  }) {
    return RpcClient.call('crear_trabajo', {
      'p_sistema_cliente_id': sistemaClienteId,
      'p_descripcion': descripcion,
      'p_fecha': fecha.toIso8601String().split('T').first,
      'p_monto': monto,
      'p_es_credito': esCredito,
    });
  }
}
