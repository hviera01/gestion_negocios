-- gestion_negocios: schema inicial
-- Panel personal de Henry para gestionar clientes/sistemas vendidos, trabajos, creditos y reportes de fallos.
-- Todo el acceso real pasa por funciones RPC security definer que validan un token de sesion propio
-- (tabla usuarios/sesiones) porque el build Web es publico en GitHub Pages y la anon key queda expuesta.

create extension if not exists pgcrypto;

-- ============================================================================
-- TABLAS
-- ============================================================================

create table sistemas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text unique not null,
  github_owner text not null,
  github_repo text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table clientes (
  id uuid primary key default gen_random_uuid(),
  nombre_negocio text not null,
  nombre_contacto text,
  telefono text,
  email text,
  notas text,
  created_at timestamptz not null default now()
);

create table sistemas_cliente (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id) on delete cascade,
  sistema_id uuid not null references sistemas(id),
  fecha_venta date not null,
  tipo_venta text not null check (tipo_venta in ('contado','mensualidades')),
  monto_total numeric(12,2) not null,
  pago_inicial numeric(12,2),
  numero_cuotas int,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table trabajos (
  id uuid primary key default gen_random_uuid(),
  sistema_cliente_id uuid not null references sistemas_cliente(id) on delete cascade,
  descripcion text not null,
  fecha date not null,
  monto numeric(12,2) not null default 0,
  es_credito boolean not null default false,
  created_at timestamptz not null default now()
);

create table creditos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id) on delete cascade,
  origen text not null check (origen in ('manual','sistema','trabajo')),
  sistema_cliente_id uuid references sistemas_cliente(id) on delete set null,
  trabajo_id uuid references trabajos(id) on delete set null,
  monto_total numeric(12,2) not null,
  saldo_pendiente numeric(12,2) not null,
  fecha_registro timestamptz not null default now(),
  fecha_vencimiento date,
  notas text,
  constraint origen_fk_check check (
    (origen = 'manual'   and sistema_cliente_id is null and trabajo_id is null) or
    (origen = 'sistema'  and sistema_cliente_id is not null and trabajo_id is null) or
    (origen = 'trabajo'  and trabajo_id is not null and sistema_cliente_id is null)
  )
);

create table cuotas (
  id uuid primary key default gen_random_uuid(),
  credito_id uuid not null references creditos(id) on delete cascade,
  numero int not null,
  fecha_vencimiento date not null,
  monto numeric(12,2) not null,
  pagada boolean not null default false,
  fecha_pago timestamptz,
  unique (credito_id, numero)
);

create table abonos (
  id uuid primary key default gen_random_uuid(),
  credito_id uuid not null references creditos(id) on delete cascade,
  fecha timestamptz not null default now(),
  monto_abonado numeric(12,2) not null,
  saldo_anterior numeric(12,2) not null,
  interes numeric(12,2) not null default 0,
  saldo_pendiente numeric(12,2) not null,
  metodo_pago text,
  numero_recibo text,
  usuario text default 'Henry'
);

create table reportes_fallos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id) on delete cascade,
  sistema_cliente_id uuid references sistemas_cliente(id) on delete set null,
  descripcion text not null,
  fecha_reporte timestamptz not null default now(),
  estado text not null default 'abierto' check (estado in ('abierto','en_progreso','resuelto')),
  cobrado boolean not null default false,
  monto_cobrado numeric(12,2),
  fecha_resolucion timestamptz,
  trabajo_id uuid references trabajos(id) on delete set null
);

create table version_cache (
  sistema_id uuid primary key references sistemas(id) on delete cascade,
  version text,
  fetched_at timestamptz not null default now()
);

create table usuarios (
  id uuid primary key default gen_random_uuid(),
  codigo_hash text not null,
  clave_hash text not null,
  created_at timestamptz not null default now()
);

create table sesiones (
  token uuid primary key default gen_random_uuid(),
  creado_at timestamptz not null default now(),
  expira_at timestamptz not null default (now() + interval '30 days')
);

-- indices
create index on creditos (cliente_id);
create index idx_creditos_pendientes on creditos (saldo_pendiente) where saldo_pendiente > 0;
create index on sistemas_cliente (cliente_id);
create index on trabajos (sistema_cliente_id);
create index on abonos (credito_id, fecha desc);
create index on cuotas (credito_id, numero);
create index on reportes_fallos (cliente_id);

-- ============================================================================
-- RLS: todo bloqueado, el acceso real es solo vía RPC security definer
-- ============================================================================

alter table sistemas enable row level security;
alter table clientes enable row level security;
alter table sistemas_cliente enable row level security;
alter table trabajos enable row level security;
alter table creditos enable row level security;
alter table cuotas enable row level security;
alter table abonos enable row level security;
alter table reportes_fallos enable row level security;
alter table version_cache enable row level security;
alter table usuarios enable row level security;
alter table sesiones enable row level security;
-- ninguna tabla tiene políticas: sin política => denegado por defecto para anon/authenticated.
-- las funciones security definer son dueñas de las tablas (mismo rol que corre la migración) y sí pueden leer/escribir.

-- ============================================================================
-- AUTH: usuarios / sesiones
-- ============================================================================

create or replace function crear_usuario_inicial(p_codigo text, p_clave text)
returns boolean
language plpgsql security definer as $$
begin
  if exists (select 1 from usuarios) then
    return false; -- ya existe un usuario, no se puede recrear desde aquí
  end if;
  insert into usuarios (codigo_hash, clave_hash)
  values (crypt(p_codigo, gen_salt('bf')), crypt(p_clave, gen_salt('bf')));
  return true;
end; $$;

create or replace function iniciar_sesion(p_codigo text, p_clave text)
returns uuid
language plpgsql security definer as $$
declare
  v_usuario usuarios;
  v_token uuid;
begin
  select * into v_usuario from usuarios limit 1;
  if v_usuario is null then
    raise exception 'No hay usuario configurado';
  end if;
  if v_usuario.codigo_hash <> crypt(p_codigo, v_usuario.codigo_hash)
     or v_usuario.clave_hash <> crypt(p_clave, v_usuario.clave_hash) then
    raise exception 'Código o clave incorrectos';
  end if;
  insert into sesiones default values returning token into v_token;
  delete from sesiones where expira_at < now();
  return v_token;
end; $$;

create or replace function cerrar_sesion(p_token uuid)
returns void
language plpgsql security definer as $$
begin
  delete from sesiones where token = p_token;
end; $$;

create or replace function _validar_sesion(p_token uuid)
returns void
language plpgsql security definer as $$
begin
  if not exists (select 1 from sesiones where token = p_token and expira_at > now()) then
    raise exception 'No autorizado';
  end if;
end; $$;

create or replace function hay_usuario_configurado()
returns boolean
language sql security definer as $$
  select exists (select 1 from usuarios);
$$;

-- ============================================================================
-- CLIENTES
-- ============================================================================

create or replace function listar_clientes(p_token uuid)
returns setof clientes
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from clientes order by nombre_negocio;
end; $$;

create or replace function crear_cliente(
  p_token uuid, p_nombre_negocio text, p_nombre_contacto text default null,
  p_telefono text default null, p_email text default null, p_notas text default null
) returns clientes
language plpgsql security definer as $$
declare v_cliente clientes;
begin
  perform _validar_sesion(p_token);
  insert into clientes (nombre_negocio, nombre_contacto, telefono, email, notas)
  values (p_nombre_negocio, p_nombre_contacto, p_telefono, p_email, p_notas)
  returning * into v_cliente;
  return v_cliente;
end; $$;

create or replace function actualizar_cliente(
  p_token uuid, p_id uuid, p_nombre_negocio text, p_nombre_contacto text default null,
  p_telefono text default null, p_email text default null, p_notas text default null
) returns clientes
language plpgsql security definer as $$
declare v_cliente clientes;
begin
  perform _validar_sesion(p_token);
  update clientes set nombre_negocio = p_nombre_negocio, nombre_contacto = p_nombre_contacto,
    telefono = p_telefono, email = p_email, notas = p_notas
  where id = p_id returning * into v_cliente;
  return v_cliente;
end; $$;

create or replace function eliminar_cliente(p_token uuid, p_id uuid)
returns void
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  delete from clientes where id = p_id;
end; $$;

-- Vista agregada de un cliente: sus sistemas, trabajos, creditos (con cuotas) y reportes de fallos.
create or replace function detalle_cliente(p_token uuid, p_cliente_id uuid)
returns json
language plpgsql security definer as $$
declare v_resultado json;
begin
  perform _validar_sesion(p_token);
  select json_build_object(
    'cliente', (select row_to_json(c) from clientes c where c.id = p_cliente_id),
    'sistemas', (
      select coalesce(json_agg(row_to_json(sc) order by sc.fecha_venta desc), '[]'::json)
      from (
        select s.id, sc.id as sistema_cliente_id, s.nombre, s.slug, sc.fecha_venta, sc.tipo_venta,
               sc.monto_total, sc.pago_inicial, sc.numero_cuotas, sc.activo
        from sistemas_cliente sc join sistemas s on s.id = sc.sistema_id
        where sc.cliente_id = p_cliente_id
      ) sc
    ),
    'trabajos', (
      select coalesce(json_agg(row_to_json(t) order by t.fecha desc), '[]'::json)
      from trabajos t
      join sistemas_cliente sc on sc.id = t.sistema_cliente_id
      where sc.cliente_id = p_cliente_id
    ),
    'creditos', (
      select coalesce(json_agg(row_to_json(cr) order by cr.fecha_registro desc), '[]'::json)
      from creditos cr where cr.cliente_id = p_cliente_id
    ),
    'reportes_fallos', (
      select coalesce(json_agg(row_to_json(r) order by r.fecha_reporte desc), '[]'::json)
      from reportes_fallos r where r.cliente_id = p_cliente_id
    )
  ) into v_resultado;
  return v_resultado;
end; $$;

-- ============================================================================
-- SISTEMAS (catálogo) + SISTEMAS_CLIENTE (instancia vendida)
-- ============================================================================

create or replace function listar_sistemas(p_token uuid)
returns setof sistemas
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from sistemas order by nombre;
end; $$;

create or replace function listar_sistemas_cliente(p_token uuid, p_cliente_id uuid default null)
returns table (
  id uuid, cliente_id uuid, sistema_id uuid, sistema_nombre text, sistema_slug text,
  fecha_venta date, tipo_venta text, monto_total numeric, pago_inicial numeric,
  numero_cuotas int, activo boolean
)
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query
    select sc.id, sc.cliente_id, sc.sistema_id, s.nombre, s.slug,
           sc.fecha_venta, sc.tipo_venta, sc.monto_total, sc.pago_inicial,
           sc.numero_cuotas, sc.activo
    from sistemas_cliente sc
    join sistemas s on s.id = sc.sistema_id
    where p_cliente_id is null or sc.cliente_id = p_cliente_id
    order by sc.fecha_venta desc;
end; $$;

create or replace function crear_sistema_cliente(
  p_token uuid, p_cliente_id uuid, p_sistema_id uuid, p_fecha_venta date,
  p_tipo_venta text, p_monto_total numeric, p_pago_inicial numeric default null,
  p_numero_cuotas int default null
) returns sistemas_cliente
language plpgsql security definer as $$
declare v_sc sistemas_cliente;
begin
  perform _validar_sesion(p_token);
  insert into sistemas_cliente (cliente_id, sistema_id, fecha_venta, tipo_venta, monto_total, pago_inicial, numero_cuotas)
  values (p_cliente_id, p_sistema_id, p_fecha_venta, p_tipo_venta, p_monto_total, p_pago_inicial, p_numero_cuotas)
  returning * into v_sc;
  return v_sc;
end; $$;

-- Trigger: venta a mensualidades genera crédito + cuotas calendarizadas automáticamente.
create or replace function trg_crear_credito_sistema() returns trigger
language plpgsql as $$
declare
  v_saldo numeric;
  v_monto_cuota numeric;
  v_credito_id uuid;
  i int;
begin
  if new.tipo_venta = 'mensualidades' and coalesce(new.numero_cuotas, 0) > 0 then
    v_saldo := new.monto_total - coalesce(new.pago_inicial, 0);
    insert into creditos (cliente_id, origen, sistema_cliente_id, monto_total, saldo_pendiente)
    values (new.cliente_id, 'sistema', new.id, v_saldo, v_saldo)
    returning id into v_credito_id;

    v_monto_cuota := trunc(v_saldo / new.numero_cuotas, 2);
    for i in 1..new.numero_cuotas loop
      insert into cuotas (credito_id, numero, fecha_vencimiento, monto)
      values (
        v_credito_id, i, new.fecha_venta + (interval '1 month' * i),
        case when i = new.numero_cuotas
          then v_saldo - v_monto_cuota * (new.numero_cuotas - 1)  -- última cuota absorbe el residuo
          else v_monto_cuota
        end
      );
    end loop;
  end if;
  return new;
end; $$;

create trigger t_credito_sistema after insert on sistemas_cliente
  for each row execute function trg_crear_credito_sistema();

-- ============================================================================
-- TRABAJOS
-- ============================================================================

create or replace function listar_trabajos(p_token uuid, p_sistema_cliente_id uuid default null)
returns setof trabajos
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from trabajos
    where p_sistema_cliente_id is null or sistema_cliente_id = p_sistema_cliente_id
    order by fecha desc;
end; $$;

create or replace function crear_trabajo(
  p_token uuid, p_sistema_cliente_id uuid, p_descripcion text, p_fecha date,
  p_monto numeric default 0, p_es_credito boolean default false
) returns trabajos
language plpgsql security definer as $$
declare v_trabajo trabajos;
begin
  perform _validar_sesion(p_token);
  insert into trabajos (sistema_cliente_id, descripcion, fecha, monto, es_credito)
  values (p_sistema_cliente_id, p_descripcion, p_fecha, p_monto, p_es_credito)
  returning * into v_trabajo;
  return v_trabajo;
end; $$;

-- Trigger: trabajo marcado a crédito genera un crédito simple (sin cuotas calendarizadas).
create or replace function trg_crear_credito_trabajo() returns trigger
language plpgsql as $$
begin
  if new.es_credito then
    insert into creditos (cliente_id, origen, trabajo_id, monto_total, saldo_pendiente)
    select sc.cliente_id, 'trabajo', new.id, new.monto, new.monto
    from sistemas_cliente sc where sc.id = new.sistema_cliente_id;
  end if;
  return new;
end; $$;

create trigger t_credito_trabajo after insert on trabajos
  for each row execute function trg_crear_credito_trabajo();

-- ============================================================================
-- CREDITOS / CUOTAS / ABONOS
-- ============================================================================

create or replace function listar_creditos(p_token uuid, p_solo_pendientes boolean default false)
returns setof creditos
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from creditos
    where not p_solo_pendientes or saldo_pendiente > 0
    order by saldo_pendiente desc, fecha_registro desc;
end; $$;

create or replace function crear_credito_manual(
  p_token uuid, p_cliente_id uuid, p_monto_total numeric,
  p_fecha_vencimiento date default null, p_notas text default null,
  p_numero_cuotas int default null
) returns creditos
language plpgsql security definer as $$
declare
  v_credito creditos;
  v_monto_cuota numeric;
  i int;
begin
  perform _validar_sesion(p_token);
  insert into creditos (cliente_id, origen, monto_total, saldo_pendiente, fecha_vencimiento, notas)
  values (p_cliente_id, 'manual', p_monto_total, p_monto_total, p_fecha_vencimiento, p_notas)
  returning * into v_credito;

  if coalesce(p_numero_cuotas, 0) > 0 then
    v_monto_cuota := trunc(p_monto_total / p_numero_cuotas, 2);
    for i in 1..p_numero_cuotas loop
      insert into cuotas (credito_id, numero, fecha_vencimiento, monto)
      values (
        v_credito.id, i, current_date + (interval '1 month' * i),
        case when i = p_numero_cuotas then p_monto_total - v_monto_cuota * (p_numero_cuotas - 1) else v_monto_cuota end
      );
    end loop;
  end if;
  return v_credito;
end; $$;

create or replace function listar_cuotas(p_token uuid, p_credito_id uuid)
returns setof cuotas
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from cuotas where credito_id = p_credito_id order by numero;
end; $$;

create or replace function listar_abonos(p_token uuid, p_credito_id uuid, p_offset int default 0, p_limit int default 50)
returns setof abonos
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from abonos where credito_id = p_credito_id
    order by fecha desc offset p_offset limit p_limit;
end; $$;

create or replace function registrar_abono(
  p_token uuid, p_credito_id uuid, p_monto_abonado numeric,
  p_interes numeric default 0, p_metodo_pago text default null,
  p_numero_recibo text default null
) returns abonos
language plpgsql security definer as $$
declare
  v_saldo_anterior numeric;
  v_saldo_nuevo numeric;
  v_abono abonos;
begin
  perform _validar_sesion(p_token);
  select saldo_pendiente into v_saldo_anterior from creditos where id = p_credito_id for update;
  if v_saldo_anterior is null then
    raise exception 'Crédito % no existe', p_credito_id;
  end if;
  v_saldo_nuevo := greatest(v_saldo_anterior - p_monto_abonado + p_interes, 0);
  update creditos set saldo_pendiente = v_saldo_nuevo where id = p_credito_id;

  -- marca cuotas pendientes como pagadas en orden, hasta cubrir el monto abonado
  update cuotas set pagada = true, fecha_pago = now()
   where id in (
     select c1.id from cuotas c1
     where c1.credito_id = p_credito_id and not c1.pagada
       and (select coalesce(sum(c2.monto), 0) from cuotas c2
            where c2.credito_id = p_credito_id and not c2.pagada and c2.numero <= c1.numero) <= p_monto_abonado
   );

  insert into abonos (credito_id, monto_abonado, saldo_anterior, interes, saldo_pendiente, metodo_pago, numero_recibo)
  values (p_credito_id, p_monto_abonado, v_saldo_anterior, p_interes, v_saldo_nuevo, p_metodo_pago, p_numero_recibo)
  returning * into v_abono;
  return v_abono;
end; $$;

-- ============================================================================
-- REPORTES DE FALLOS
-- ============================================================================

create or replace function listar_reportes_fallos(p_token uuid, p_estado text default null)
returns setof reportes_fallos
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query select * from reportes_fallos
    where p_estado is null or estado = p_estado
    order by fecha_reporte desc;
end; $$;

create or replace function crear_reporte_fallo(
  p_token uuid, p_cliente_id uuid, p_sistema_cliente_id uuid, p_descripcion text
) returns reportes_fallos
language plpgsql security definer as $$
declare v_reporte reportes_fallos;
begin
  perform _validar_sesion(p_token);
  insert into reportes_fallos (cliente_id, sistema_cliente_id, descripcion)
  values (p_cliente_id, p_sistema_cliente_id, p_descripcion)
  returning * into v_reporte;
  return v_reporte;
end; $$;

create or replace function actualizar_reporte_fallo(
  p_token uuid, p_id uuid, p_estado text default null,
  p_cobrado boolean default null, p_monto_cobrado numeric default null
) returns reportes_fallos
language plpgsql security definer as $$
declare v_reporte reportes_fallos;
begin
  perform _validar_sesion(p_token);
  update reportes_fallos set
    estado = coalesce(p_estado, estado),
    cobrado = coalesce(p_cobrado, cobrado),
    monto_cobrado = coalesce(p_monto_cobrado, monto_cobrado),
    fecha_resolucion = case when p_estado = 'resuelto' then now() else fecha_resolucion end
  where id = p_id
  returning * into v_reporte;
  return v_reporte;
end; $$;

create or replace function convertir_reporte_en_trabajo(
  p_token uuid, p_reporte_id uuid, p_monto numeric, p_es_credito boolean default false
) returns trabajos
language plpgsql security definer as $$
declare
  v_reporte reportes_fallos;
  v_trabajo trabajos;
begin
  perform _validar_sesion(p_token);
  select * into v_reporte from reportes_fallos where id = p_reporte_id;
  if v_reporte.sistema_cliente_id is null then
    raise exception 'El reporte no tiene un sistema asociado, no se puede convertir en trabajo';
  end if;
  insert into trabajos (sistema_cliente_id, descripcion, fecha, monto, es_credito)
  values (v_reporte.sistema_cliente_id, 'Fix: ' || v_reporte.descripcion, current_date, p_monto, p_es_credito)
  returning * into v_trabajo;
  update reportes_fallos set trabajo_id = v_trabajo.id, cobrado = (p_monto > 0), monto_cobrado = p_monto
  where id = p_reporte_id;
  return v_trabajo;
end; $$;

-- ============================================================================
-- VERSION CACHE (chequeo de versión vía GitHub Releases, ver VersionSistemaService en Flutter)
-- ============================================================================

create or replace function obtener_version_cache(p_token uuid, p_sistema_id uuid)
returns version_cache
language plpgsql security definer as $$
declare v_cache version_cache;
begin
  perform _validar_sesion(p_token);
  select * into v_cache from version_cache where sistema_id = p_sistema_id;
  return v_cache;
end; $$;

create or replace function upsert_version_cache(p_token uuid, p_sistema_id uuid, p_version text)
returns version_cache
language plpgsql security definer as $$
declare v_cache version_cache;
begin
  perform _validar_sesion(p_token);
  insert into version_cache (sistema_id, version, fetched_at)
  values (p_sistema_id, p_version, now())
  on conflict (sistema_id) do update set version = excluded.version, fetched_at = excluded.fetched_at
  returning * into v_cache;
  return v_cache;
end; $$;

-- ============================================================================
-- DASHBOARD
-- ============================================================================

create or replace function resumen_dashboard(p_token uuid)
returns json
language plpgsql security definer as $$
declare v_resultado json;
begin
  perform _validar_sesion(p_token);
  select json_build_object(
    'saldo_pendiente_total', (select coalesce(sum(saldo_pendiente), 0) from creditos),
    'reportes_abiertos', (select count(*) from reportes_fallos where estado <> 'resuelto'),
    'total_clientes', (select count(*) from clientes),
    'abonos_recientes', (
      select coalesce(json_agg(row_to_json(a) order by a.fecha desc), '[]'::json)
      from (select * from abonos order by fecha desc limit 10) a
    ),
    'creditos_vencidos', (
      select count(*) from creditos where saldo_pendiente > 0 and fecha_vencimiento < current_date
    )
  ) into v_resultado;
  return v_resultado;
end; $$;

-- ============================================================================
-- SEED: catálogo de sistemas ya vendidos
-- ============================================================================

insert into sistemas (nombre, slug, github_owner, github_repo) values
  ('Lopsi', 'lopsi', 'hviera01', 'VariedadesLopsi'),
  ('Autofrenos Oriente', 'autofrenos', 'hviera01', 'AutoFrenosOriente'),
  ('Barbería', 'barberia', 'hviera01', 'DanielBarberShop'),
  ('SIEG', 'sieg', 'hviera01', 'CapitalExpress');
