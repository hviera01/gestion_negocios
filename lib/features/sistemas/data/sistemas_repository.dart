import '../../../core/data/rpc_client.dart';
import '../../../core/models/sistema_model.dart';
import 'sistema_cliente_model.dart';

class SistemasRepository {
  Future<List<SistemaModel>> listarCatalogo() async {
    final res = await RpcClient.call('listar_sistemas');
    return (res as List).map((e) => SistemaModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<SistemaModel> crearSistema({
    required String nombre,
    required String slug,
    String? githubOwner,
    String? githubRepo,
  }) async {
    final res = await RpcClient.call('crear_sistema', {
      'p_nombre': nombre,
      'p_slug': slug,
      'p_github_owner': githubOwner,
      'p_github_repo': githubRepo,
    });
    return SistemaModel.fromMap(res as Map<String, dynamic>);
  }

  Future<List<SistemaClienteModel>> listarVendidos({String? clienteId}) async {
    final res = await RpcClient.call('listar_sistemas_cliente', {'p_cliente_id': clienteId});
    return (res as List).map((e) => SistemaClienteModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> venderSistema({
    required String clienteId,
    required String sistemaId,
    required DateTime fechaVenta,
    required String tipoVenta,
    required double montoTotal,
    double? pagoInicial,
    int? numeroCuotas,
  }) {
    return RpcClient.call('crear_sistema_cliente', {
      'p_cliente_id': clienteId,
      'p_sistema_id': sistemaId,
      'p_fecha_venta': fechaVenta.toIso8601String().split('T').first,
      'p_tipo_venta': tipoVenta,
      'p_monto_total': montoTotal,
      'p_pago_inicial': pagoInicial,
      'p_numero_cuotas': numeroCuotas,
    });
  }
}
