-- Permite agregar nuevos sistemas al catálogo desde la app (antes solo existían
-- los 4 sembrados en 0001_init.sql). Correr esto una vez en el SQL Editor de Supabase.

create or replace function crear_sistema(
  p_token uuid, p_nombre text, p_slug text,
  p_github_owner text default null, p_github_repo text default null
) returns sistemas
language plpgsql security definer as $$
declare v_sistema sistemas;
begin
  perform _validar_sesion(p_token);
  insert into sistemas (nombre, slug, github_owner, github_repo)
  values (p_nombre, p_slug, coalesce(nullif(p_github_owner, ''), p_slug), coalesce(nullif(p_github_repo, ''), p_slug))
  returning * into v_sistema;
  return v_sistema;
end; $$;
