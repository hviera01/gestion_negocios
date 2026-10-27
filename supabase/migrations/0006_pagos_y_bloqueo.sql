-- (1) Bloqueo/aviso del sistema de cada cliente desde el panel: cada venta tiene un
--     codigo_acceso secreto que el sistema del cliente consulta (sin sesion) para saber
--     si esta activo, en aviso o bloqueado.
-- (2) Registrar un pago con fecha propia, y editar/borrar pagos ya registrados.
-- (3) listar_cobros devuelve la venta y su estado de servicio para bloquear desde Cobros.
-- Requiere 0005_cobros.sql aplicada antes.

alter table sistemas_cliente add column if not exists estado_servicio text not null default 'activo';
alter table sistemas_cliente drop constraint if exists sistemas_cliente_estado_servicio_check;
alter table sistemas_cliente add constraint sistemas_cliente_estado_servicio_check
  check (estado_servicio in ('activo','aviso','bloqueado'));
alter table sistemas_cliente add column if not exists mensaje_servicio text;
alter table sistemas_cliente add column if not exists codigo_acceso uuid not null default gen_random_uuid();
create unique index if not exists idx_sistemas_cliente_codigo_acceso on sistemas_cliente (codigo_acceso);

create or replace function consultar_estado_servicio(p_codigo uuid)
returns table (estado text, mensaje text)
language sql security definer stable as $$
  select sc.estado_servicio, sc.mensaje_servicio
  from sistemas_cliente sc
  where sc.codigo_acceso = p_codigo;
$$;

create or replace function cambiar_estado_servicio(
  p_token uuid, p_id uuid, p_estado text, p_mensaje text default null
) returns sistemas_cliente
language plpgsql security definer as $$
declare v_sc sistemas_cliente;
begin
  perform _validar_sesion(p_token);
  if p_estado not in ('activo','aviso','bloqueado') then
    raise exception 'Estado inválido';
  end if;
  update sistemas_cliente set estado_servicio = p_estado, mensaje_servicio = p_mensaje
  where id = p_id
  returning * into v_sc;
  if v_sc.id is null then
    raise exception 'Venta no encontrada';
  end if;
  return v_sc;
end; $$;

drop function if exists listar_sistemas_cliente(uuid, uuid);

create or replace function listar_sistemas_cliente(p_token uuid, p_cliente_id uuid default null)
returns table (
  id uuid, cliente_id uuid, sistema_id uuid, sistema_nombre text, sistema_slug text,
  fecha_venta date, tipo_venta text, monto_total numeric, pago_inicial numeric,
  numero_cuotas int, monto_mensual numeric, fecha_primer_pago date, activo boolean,
  estado_servicio text, mensaje_servicio text, codigo_acceso uuid, cliente_nombre text
)
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query
    select sc.id, sc.cliente_id, sc.sistema_id, s.nombre, s.slug,
           sc.fecha_venta, sc.tipo_venta, sc.monto_total, sc.pago_inicial,
           sc.numero_cuotas, sc.monto_mensual, sc.fecha_primer_pago, sc.activo,
           sc.estado_servicio, sc.mensaje_servicio, sc.codigo_acceso, c.nombre_negocio
    from sistemas_cliente sc
    join sistemas s on s.id = sc.sistema_id
    join clientes c on c.id = sc.cliente_id
    where p_cliente_id is null or sc.cliente_id = p_cliente_id
    order by sc.fecha_venta desc;
end; $$;

-- ============================================================================
-- Cobros: agrega la venta y su estado de servicio
-- ============================================================================

drop function if exists listar_cobros(uuid);

create or replace function listar_cobros(p_token uuid)
returns table (
  tipo text, referencia_id uuid, credito_id uuid, cliente_id uuid, cliente_nombre text,
  concepto text, monto numeric, fecha_vencimiento date,
  numero_cuota int, total_cuotas int, saldo_pendiente numeric,
  venta_id uuid, estado_servicio text
)
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  perform generar_cargos_mensuales();
  return query
    select 'suscripcion'::text, sc.id, cr.id, sc.cliente_id, c.nombre_negocio,
           s.nombre, sc.monto_mensual, sc.proximo_pago,
           null::int, null::int, cr.saldo_pendiente,
           sc.id, sc.estado_servicio
    from sistemas_cliente sc
    join clientes c on c.id = sc.cliente_id
    join sistemas s on s.id = sc.sistema_id
    join creditos cr on cr.sistema_cliente_id = sc.id
    where sc.tipo_venta = 'suscripcion' and sc.activo = true and sc.proximo_pago is not null
    union all
    select 'cuota'::text, q.id, cr.id, cr.cliente_id, c.nombre_negocio,
           coalesce(s.nombre, case cr.origen when 'trabajo' then 'Trabajo' else 'Crédito' end),
           q.monto, q.fecha_vencimiento,
           q.numero, (select count(*)::int from cuotas q2 where q2.credito_id = cr.id), cr.saldo_pendiente,
           sc.id, sc.estado_servicio
    from cuotas q
    join creditos cr on cr.id = q.credito_id
    join clientes c on c.id = cr.cliente_id
    left join sistemas_cliente sc on sc.id = cr.sistema_cliente_id
    left join sistemas s on s.id = sc.sistema_id
    where not q.pagada and cr.saldo_pendiente > 0
      and q.numero = (select min(q3.numero) from cuotas q3 where q3.credito_id = cr.id and not q3.pagada)
    order by 8, 5;
end; $$;

-- ============================================================================
-- Pagos: fecha propia al registrar, editar y borrar
-- ============================================================================

drop function if exists registrar_abono(uuid, uuid, numeric, numeric, text, text);

create or replace function registrar_abono(
  p_token uuid, p_credito_id uuid, p_monto_abonado numeric,
  p_interes numeric default 0, p_metodo_pago text default null,
  p_numero_recibo text default null, p_fecha timestamptz default null
) returns abonos
language plpgsql security definer as $$
declare
  v_saldo_anterior numeric;
  v_saldo_nuevo numeric;
  v_fecha timestamptz := coalesce(p_fecha, now());
  v_abono abonos;
begin
  perform _validar_sesion(p_token);
  select saldo_pendiente into v_saldo_anterior from creditos where id = p_credito_id for update;
  if v_saldo_anterior is null then
    raise exception 'Crédito % no existe', p_credito_id;
  end if;
  v_saldo_nuevo := greatest(v_saldo_anterior - p_monto_abonado + p_interes, 0);
  update creditos set saldo_pendiente = v_saldo_nuevo where id = p_credito_id;

  update cuotas set pagada = true, fecha_pago = v_fecha
   where id in (
     select c1.id from cuotas c1
     where c1.credito_id = p_credito_id and not c1.pagada
       and (select coalesce(sum(c2.monto), 0) from cuotas c2
            where c2.credito_id = p_credito_id and not c2.pagada and c2.numero <= c1.numero) <= p_monto_abonado
   );

  insert into abonos (credito_id, fecha, monto_abonado, saldo_anterior, interes, saldo_pendiente, metodo_pago, numero_recibo)
  values (p_credito_id, v_fecha, p_monto_abonado, v_saldo_anterior, p_interes, v_saldo_nuevo, p_metodo_pago, p_numero_recibo)
  returning * into v_abono;
  return v_abono;
end; $$;

create or replace function _recalcular_cuotas(p_credito_id uuid)
returns void
language plpgsql security definer as $$
declare v_total numeric;
begin
  select coalesce(sum(monto_abonado), 0) into v_total from abonos where credito_id = p_credito_id;
  with acum as (
    select id, sum(monto) over (order by numero) as a from cuotas where credito_id = p_credito_id
  )
  update cuotas q set
    pagada = (acum.a <= v_total + 0.005),
    fecha_pago = case when acum.a <= v_total + 0.005 then coalesce(q.fecha_pago, now()) else null end
  from acum where q.id = acum.id;
end; $$;

create or replace function editar_abono(
  p_token uuid, p_abono_id uuid, p_fecha timestamptz, p_monto_abonado numeric,
  p_interes numeric default 0, p_metodo_pago text default null, p_numero_recibo text default null
) returns abonos
language plpgsql security definer as $$
declare
  v_a abonos;
  v_delta numeric;
begin
  perform _validar_sesion(p_token);
  select * into v_a from abonos where id = p_abono_id for update;
  if v_a.id is null then
    raise exception 'Pago no encontrado';
  end if;
  if p_monto_abonado <= 0 then
    raise exception 'El monto debe ser mayor a cero';
  end if;

  v_delta := (v_a.monto_abonado - v_a.interes) - (p_monto_abonado - coalesce(p_interes, 0));

  update creditos set saldo_pendiente = greatest(saldo_pendiente + v_delta, 0) where id = v_a.credito_id;
  update abonos set
    saldo_anterior = saldo_anterior + v_delta,
    saldo_pendiente = greatest(saldo_pendiente + v_delta, 0)
  where credito_id = v_a.credito_id and id <> v_a.id and fecha > v_a.fecha;

  update abonos set
    fecha = coalesce(p_fecha, fecha),
    monto_abonado = p_monto_abonado,
    interes = coalesce(p_interes, 0),
    saldo_pendiente = greatest(saldo_anterior - p_monto_abonado + coalesce(p_interes, 0), 0),
    metodo_pago = p_metodo_pago,
    numero_recibo = p_numero_recibo
  where id = v_a.id
  returning * into v_a;

  perform _recalcular_cuotas(v_a.credito_id);
  return v_a;
end; $$;

create or replace function eliminar_abono(p_token uuid, p_abono_id uuid)
returns void
language plpgsql security definer as $$
declare
  v_a abonos;
  v_delta numeric;
  v_sc_id uuid;
begin
  perform _validar_sesion(p_token);
  select * into v_a from abonos where id = p_abono_id for update;
  if v_a.id is null then
    raise exception 'Pago no encontrado';
  end if;

  v_delta := v_a.monto_abonado - v_a.interes;
  update creditos set saldo_pendiente = greatest(saldo_pendiente + v_delta, 0) where id = v_a.credito_id;
  update abonos set
    saldo_anterior = saldo_anterior + v_delta,
    saldo_pendiente = greatest(saldo_pendiente + v_delta, 0)
  where credito_id = v_a.credito_id and id <> v_a.id and fecha > v_a.fecha;
  delete from abonos where id = v_a.id;

  perform _recalcular_cuotas(v_a.credito_id);

  select sc.id into v_sc_id
  from creditos cr join sistemas_cliente sc on sc.id = cr.sistema_cliente_id
  where cr.id = v_a.credito_id and sc.tipo_venta = 'suscripcion';
  if v_sc_id is not null then
    update sistemas_cliente set
      proximo_pago = (proximo_pago - interval '1 month')::date,
      periodos_cargados = periodos_cargados + 1
    where id = v_sc_id;
    perform _sincronizar_cargos_suscripcion(v_sc_id);
  end if;
end; $$;

-- registrar_pago_suscripcion: acepta fecha del pago
drop function if exists registrar_pago_suscripcion(uuid, uuid, numeric, text, text);

create or replace function registrar_pago_suscripcion(
  p_token uuid, p_sistema_cliente_id uuid, p_monto numeric default null,
  p_metodo_pago text default null, p_numero_recibo text default null,
  p_fecha timestamptz default null
) returns sistemas_cliente
language plpgsql security definer as $$
declare
  v_sc sistemas_cliente;
  v_credito_id uuid;
  v_monto numeric;
begin
  perform _validar_sesion(p_token);
  select * into v_sc from sistemas_cliente where id = p_sistema_cliente_id and tipo_venta = 'suscripcion' for update;
  if v_sc.id is null then
    raise exception 'Suscripción no encontrada';
  end if;
  select id into v_credito_id from creditos where sistema_cliente_id = v_sc.id;
  v_monto := coalesce(p_monto, v_sc.monto_mensual);
  if v_monto < v_sc.monto_mensual then
    raise exception 'El pago debe cubrir la mensualidad completa (para pagos parciales usá un abono en Créditos)';
  end if;

  perform _sincronizar_cargos_suscripcion(v_sc.id);
  select * into v_sc from sistemas_cliente where id = v_sc.id;
  if v_sc.periodos_cargados = 0 then
    update creditos set saldo_pendiente = saldo_pendiente + v_sc.monto_mensual where id = v_credito_id;
    insert into cargos_suscripcion (credito_id, monto) values (v_credito_id, v_sc.monto_mensual);
    update sistemas_cliente set periodos_cargados = 1 where id = v_sc.id;
  end if;

  perform registrar_abono(p_token, v_credito_id, v_monto, 0, p_metodo_pago, p_numero_recibo, p_fecha);

  update sistemas_cliente set
    periodos_cargados = greatest(periodos_cargados - 1, 0),
    proximo_pago = (proximo_pago + interval '1 month')::date
  where id = v_sc.id
  returning * into v_sc;
  return v_sc;
end; $$;
