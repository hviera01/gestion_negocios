import '../../../core/data/rpc_client.dart';
import 'cliente_model.dart';

class ClientesRepository {
  Future<List<ClienteModel>> listar() async {
    final res = await RpcClient.call('listar_clientes');
    return (res as List).map((e) => ClienteModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<ClienteModel> crear({
    required String nombreNegocio,
    String? nombreContacto,
    String? telefono,
    String? email,
    String? notas,
  }) async {
    final res = await RpcClient.call('crear_cliente', {
      'p_nombre_negocio': nombreNegocio,
      'p_nombre_contacto': nombreContacto,
      'p_telefono': telefono,
      'p_email': email,
      'p_notas': notas,
    });
    return ClienteModel.fromMap(res as Map<String, dynamic>);
  }

  Future<ClienteModel> actualizar({
    required String id,
    required String nombreNegocio,
    String? nombreContacto,
    String? telefono,
    String? email,
    String? notas,
  }) async {
    final res = await RpcClient.call('actualizar_cliente', {
      'p_id': id,
      'p_nombre_negocio': nombreNegocio,
      'p_nombre_contacto': nombreContacto,
      'p_telefono': telefono,
      'p_email': email,
      'p_notas': notas,
    });
    return ClienteModel.fromMap(res as Map<String, dynamic>);
  }

  Future<void> eliminar(String id) => RpcClient.call('eliminar_cliente', {'p_id': id});

  Future<Map<String, dynamic>> detalle(String clienteId) async {
    final res = await RpcClient.call('detalle_cliente', {'p_cliente_id': clienteId});
    return res as Map<String, dynamic>;
  }
}
