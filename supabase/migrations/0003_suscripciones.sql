-- Agrega un tercer tipo de venta: 'suscripcion' — pago inicial (ya cobrado, no genera
-- deuda) + una mensualidad que se repite indefinidamente (sin numero de cuotas fijo).
-- Cada mes se le suma monto_mensual al saldo_pendiente del credito; los abonos lo bajan
-- igual que siempre. cargos_suscripcion evita cobrar el mismo mes dos veces.

alter table sistemas_cliente alter column monto_total drop not null;
alter table sistemas_cliente add column if not exists monto_mensual numeric(12,2);

alter table sistemas_cliente drop constraint if exists sistemas_cliente_tipo_venta_check;
alter table sistemas_cliente add constraint sistemas_cliente_tipo_venta_check
  check (tipo_venta in ('contado','mensualidades','suscripcion'));

create table if not exists cargos_suscripcion (
  id uuid primary key default gen_random_uuid(),
  credito_id uuid not null references creditos(id) on delete cascade,
  fecha timestamptz not null default now(),
  monto numeric(12,2) not null
);
alter table cargos_suscripcion enable row level security;
create index if not exists idx_cargos_suscripcion_credito_mes on cargos_suscripcion (credito_id, fecha);

-- reemplaza el trigger de creacion de credito para sumar el caso 'suscripcion'
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
          then v_saldo - v_monto_cuota * (new.numero_cuotas - 1)
          else v_monto_cuota
        end
      );
    end loop;
  elsif new.tipo_venta = 'suscripcion' then
    -- el pago inicial se asume cobrado al firmar: el credito arranca en 0 y
    -- generar_cargos_mensuales() le va sumando la mensualidad mes a mes.
    insert into creditos (cliente_id, origen, sistema_cliente_id, monto_total, saldo_pendiente, notas)
    values (new.cliente_id, 'sistema', new.id, new.monto_mensual, 0, 'Suscripción mensual');
  end if;
  return new;
end; $$;

-- crear_sistema_cliente: agrega p_monto_mensual y hace p_monto_total opcional
create or replace function crear_sistema_cliente(
  p_token uuid, p_cliente_id uuid, p_sistema_id uuid, p_fecha_venta date,
  p_tipo_venta text, p_monto_total numeric default null, p_pago_inicial numeric default null,
  p_numero_cuotas int default null, p_monto_mensual numeric default null
) returns sistemas_cliente
language plpgsql security definer as $$
declare v_sc sistemas_cliente;
begin
  perform _validar_sesion(p_token);
  insert into sistemas_cliente (cliente_id, sistema_id, fecha_venta, tipo_venta, monto_total, pago_inicial, numero_cuotas, monto_mensual)
  values (p_cliente_id, p_sistema_id, p_fecha_venta, p_tipo_venta, p_monto_total, p_pago_inicial, p_numero_cuotas, p_monto_mensual)
  returning * into v_sc;
  return v_sc;
end; $$;

-- listar_sistemas_cliente: agrega monto_mensual a la salida
create or replace function listar_sistemas_cliente(p_token uuid, p_cliente_id uuid default null)
returns table (
  id uuid, cliente_id uuid, sistema_id uuid, sistema_nombre text, sistema_slug text,
  fecha_venta date, tipo_venta text, monto_total numeric, pago_inicial numeric,
  numero_cuotas int, monto_mensual numeric, activo boolean
)
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query
    select sc.id, sc.cliente_id, sc.sistema_id, s.nombre, s.slug,
           sc.fecha_venta, sc.tipo_venta, sc.monto_total, sc.pago_inicial,
           sc.numero_cuotas, sc.monto_mensual, sc.activo
    from sistemas_cliente sc
    join sistemas s on s.id = sc.sistema_id
    where p_cliente_id is null or sc.cliente_id = p_cliente_id
    order by sc.fecha_venta desc;
end; $$;

-- corre mes a mes (via GitHub Actions cron, ver .github/workflows/cargos_suscripcion.yml).
-- no exige sesion: no tiene parametros controlables por el llamante y esta acotada al mes
-- calendario real, así que no hay nada que explotar llamandola de más.
create or replace function generar_cargos_mensuales()
returns int
language plpgsql security definer as $$
declare
  v_row record;
  v_contador int := 0;
begin
  for v_row in
    select cr.id as credito_id, sc.monto_mensual
    from sistemas_cliente sc
    join creditos cr on cr.sistema_cliente_id = sc.id
    where sc.tipo_venta = 'suscripcion' and sc.activo = true and coalesce(sc.monto_mensual, 0) > 0
  loop
    if not exists (
      select 1 from cargos_suscripcion cs
      where cs.credito_id = v_row.credito_id
        and date_trunc('month', cs.fecha) = date_trunc('month', now())
    ) then
      update creditos set saldo_pendiente = saldo_pendiente + v_row.monto_mensual
      where id = v_row.credito_id;
      insert into cargos_suscripcion (credito_id, monto) values (v_row.credito_id, v_row.monto_mensual);
      v_contador := v_contador + 1;
    end if;
  end loop;
  return v_contador;
end; $$;
