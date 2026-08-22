import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/supabase_client.dart';
import '../models/sistema_model.dart';
import 'session_service.dart';

/// Consulta la versión publicada de un sistema cliente vía GitHub Releases (público,
/// sin token — mismo patrón que ActualizacionService en los sistemas hermanos), cacheado
/// en la tabla version_cache para no golpear el límite de 60 req/hora sin auth de GitHub
/// ni recargar el dashboard con llamadas repetidas.
class VersionSistemaService {
  VersionSistemaService._();

  static const _ttl = Duration(hours: 6);

  static Future<String?> obtenerVersion(SistemaModel sistema) async {
    final token = await SessionService.instance.obtenerToken();
    if (token == null) return null;

    try {
      final cache = await supabase.rpc('obtener_version_cache', params: {
        'p_token': token,
        'p_sistema_id': sistema.id,
      });
      if (cache != null) {
        final fetchedAt = DateTime.tryParse(cache['fetched_at'] as String? ?? '');
        if (fetchedAt != null && DateTime.now().difference(fetchedAt) < _ttl) {
          return cache['version'] as String?;
        }
      }

      final version = await _fetchDesdeGithub(sistema.githubOwner, sistema.githubRepo);
      if (version != null) {
        await supabase.rpc('upsert_version_cache', params: {
          'p_token': token,
          'p_sistema_id': sistema.id,
          'p_version': version,
        });
        return version;
      }
      return cache?['version'] as String?; // fallback: valor viejo si GitHub no respondió
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchDesdeGithub(String owner, String repo) async {
    try {
      final respuesta = await http
          .get(
            Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return null;
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final tag = (datos['tag_name'] as String? ?? '').trim();
      return tag.isEmpty ? null : tag;
    } catch (_) {
      return null;
    }
  }
}
