import '../services/session_service.dart';
import 'supabase_client.dart';

/// Envuelve supabase.rpc inyectando automáticamente p_token (sesión propia,
/// ver session_service.dart y las funciones security definer en 0001_init.sql).
class RpcClient {
  RpcClient._();

  static Future<dynamic> call(String funcion, [Map<String, dynamic> params = const {}]) async {
    final token = await SessionService.instance.obtenerToken();
    if (token == null) {
      throw StateError('No hay sesión activa');
    }
    return supabase.rpc(funcion, params: {'p_token': token, ...params});
  }
}
