/// Credenciales del proyecto Supabase de gestion_negocios.
///
/// La anon key es pública por diseño (viaja en el bundle web/móvil) — la seguridad
/// real vive en las funciones RPC (ver supabase/migrations/0001_init.sql), no en esta key.
/// Reemplazar con los valores del proyecto una vez creado en https://supabase.com/dashboard.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://okruxiibzqkgjgwtlyzm.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2IY1WVlBKqRnuUgdwWEfkQ_hbk_5mXX',
  );
}
