import '../../../core/data/rpc_client.dart';
import 'credito_model.dart';

class CreditosRepository {
  Future<List<CreditoModel>> listar({bool soloPendientes = false}) async {
    final res = await RpcClient.call('listar_creditos', {'p_solo_pendientes': soloPendientes});
    return (res as List).map((e) => CreditoModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> crearManual({
    required String clienteId,
    required double montoTotal,
    DateTime? fechaVencimiento,
    String? notas,
    int? numeroCuotas,
  }) {
    return RpcClient.call('crear_credito_manual', {
      'p_cliente_id': clienteId,
      'p_monto_total': montoTotal,
      'p_fecha_vencimiento': fechaVencimiento?.toIso8601String().split('T').first,
      'p_notas': notas,
      'p_numero_cuotas': numeroCuotas,
    });
  }

  Future<List<CuotaModel>> listarCuotas(String creditoId) async {
    final res = await RpcClient.call('listar_cuotas', {'p_credito_id': creditoId});
    return (res as List).map((e) => CuotaModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<AbonoModel>> listarAbonos(String creditoId, {int offset = 0, int limit = 50}) async {
    final res = await RpcClient.call('listar_abonos', {
      'p_credito_id': creditoId,
      'p_offset': offset,
      'p_limit': limit,
    });
    return (res as List).map((e) => AbonoModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> registrarAbono({
    required String creditoId,
    required double montoAbonado,
    double interes = 0,
    String? metodoPago,
    String? numeroRecibo,
  }) {
    return RpcClient.call('registrar_abono', {
      'p_credito_id': creditoId,
      'p_monto_abonado': montoAbonado,
      'p_interes': interes,
      'p_metodo_pago': metodoPago,
      'p_numero_recibo': numeroRecibo,
    });
  }
}
