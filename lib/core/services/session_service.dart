import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/supabase_client.dart';

/// Maneja el token de sesión propio (tabla `sesiones`, no Supabase Auth).
/// Se guarda cifrado en el dispositivo — nunca el código/clave en texto plano.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'gn_session_token';

  String? _cachedToken;

  Future<String?> obtenerToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  Future<bool> haySesionGuardada() async => (await obtenerToken()) != null;

  Future<bool> hayUsuarioConfigurado() async {
    final res = await supabase.rpc('hay_usuario_configurado');
    return res as bool;
  }

  Future<bool> crearUsuarioInicial(String codigo, String clave) async {
    final res = await supabase.rpc('crear_usuario_inicial', params: {
      'p_codigo': codigo,
      'p_clave': clave,
    });
    return res as bool;
  }

  Future<String> iniciarSesion(String codigo, String clave) async {
    final token = await supabase.rpc('iniciar_sesion', params: {
      'p_codigo': codigo,
      'p_clave': clave,
    }) as String;
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
    return token;
  }

  Future<void> cerrarSesion() async {
    final token = await obtenerToken();
    if (token != null) {
      try {
        await supabase.rpc('cerrar_sesion', params: {'p_token': token});
      } catch (_) {
        // si ya expiró o no existe, igual limpiamos localmente
      }
    }
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }
}
