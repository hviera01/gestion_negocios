-- Gestion de cobros: cada suscripcion tiene una fecha de proximo pago (editable) que
-- avanza un mes al marcar el pago, los cargos se generan segun esa fecha (no el dia 1
-- del mes calendario), y listar_cobros junta suscripciones y cuotas pendientes en una
-- sola lista ordenada por fecha para ver quien debe y cuando le toca pagar.

alter table sistemas_cliente add column if not exists proximo_pago date;
alter table sistemas_cliente add column if not exists periodos_cargados int not null default 0;

update sistemas_cliente
set proximo_pago = coalesce(fecha_primer_pago, fecha_venta)
where tipo_venta = 'suscripcion' and proximo_pago is null;

create or replace function _hoy_hn() returns date
language sql stable as $$ select (now() at time zone 'America/Tegucigalpa')::date $$;

-- Deja el credito de una suscripcion con un cargo por cada periodo ya vencido y aun no
-- pagado (periodo j vence en proximo_pago + j meses). Si la fecha se mueve hacia
-- adelante y quedan cargos de mas, los devuelve.
create or replace function _sincronizar_cargos_suscripcion(p_sc_id uuid)
returns void
language plpgsql security definer as $$
declare
  v_sc sistemas_cliente;
  v_credito_id uuid;
  v_hoy date := _hoy_hn();
  v_vencidos int;
  v_dif int;
begin
  select * into v_sc from sistemas_cliente where id = p_sc_id for update;
  if v_sc.id is null or v_sc.tipo_venta <> 'suscripcion' or v_sc.proximo_pago is null then
    return;
  end if;
  select id into v_credito_id from creditos where sistema_cliente_id = p_sc_id;
  if v_credito_id is null then
    return;
  end if;

  if v_sc.proximo_pago > v_hoy then
    v_vencidos := 0;
  else
    v_vencidos := 1;
    while (v_sc.proximo_pago + (interval '1 month' * v_vencidos))::date <= v_hoy loop
      v_vencidos := v_vencidos + 1;
    end loop;
  end if;

  v_dif := v_vencidos - v_sc.periodos_cargados;
  if v_dif = 0 then
    return;
  end if;

  update creditos
  set saldo_pendiente = greatest(saldo_pendiente + v_dif * coalesce(v_sc.monto_mensual, 0), 0)
  where id = v_credito_id;
  if v_dif > 0 then
    insert into cargos_suscripcion (credito_id, monto)
    select v_credito_id, v_sc.monto_mensual from generate_series(1, v_dif);
  end if;
  update sistemas_cliente set periodos_cargados = v_vencidos where id = p_sc_id;
end; $$;

-- corre todos los dias (GitHub Actions): carga los periodos que ya vencieron
create or replace function generar_cargos_mensuales()
returns int
language plpgsql security definer as $$
declare
  v_id uuid;
  v_antes int;
  v_contador int := 0;
begin
  for v_id in
    select id from sistemas_cliente
    where tipo_venta = 'suscripcion' and activo = true and coalesce(monto_mensual, 0) > 0
  loop
    select periodos_cargados into v_antes from sistemas_cliente where id = v_id;
    perform _sincronizar_cargos_suscripcion(v_id);
    if (select periodos_cargados from sistemas_cliente where id = v_id) <> v_antes then
      v_contador := v_contador + 1;
    end if;
  end loop;
  return v_contador;
end; $$;

select generar_cargos_mensuales();

-- ============================================================================
-- crear / actualizar venta: fija proximo_pago en las suscripciones
-- ============================================================================

create or replace function crear_sistema_cliente(
  p_token uuid, p_cliente_id uuid, p_sistema_id uuid, p_fecha_venta date,
  p_tipo_venta text, p_monto_total numeric default null, p_pago_inicial numeric default null,
  p_numero_cuotas int default null, p_monto_mensual numeric default null,
  p_fecha_primer_pago date default null
) returns sistemas_cliente
language plpgsql security definer as $$
declare v_sc sistemas_cliente;
begin
  perform _validar_sesion(p_token);
  insert into sistemas_cliente (cliente_id, sistema_id, fecha_venta, tipo_venta, monto_total, pago_inicial, numero_cuotas, monto_mensual, fecha_primer_pago, proximo_pago)
  values (p_cliente_id, p_sistema_id, p_fecha_venta, p_tipo_venta, p_monto_total, p_pago_inicial, p_numero_cuotas, p_monto_mensual, p_fecha_primer_pago,
          case when p_tipo_venta = 'suscripcion' then coalesce(p_fecha_primer_pago, p_fecha_venta) end)
  returning * into v_sc;

  perform _sincronizar_cargos_suscripcion(v_sc.id);
  select * into v_sc from sistemas_cliente where id = v_sc.id;
  return v_sc;
end; $$;

create or replace function actualizar_sistema_cliente(
  p_token uuid, p_id uuid, p_cliente_id uuid, p_sistema_id uuid, p_fecha_venta date,
  p_tipo_venta text, p_monto_total numeric default null, p_pago_inicial numeric default null,
  p_numero_cuotas int default null, p_monto_mensual numeric default null,
  p_fecha_primer_pago date default null
) returns sistemas_cliente
language plpgsql security definer as $$
declare
  v_sc sistemas_cliente;
  v_credito_id uuid;
  v_tiene_abonos boolean;
  v_saldo numeric;
  v_monto_cuota numeric;
  v_fecha_base date;
  i int;
begin
  perform _validar_sesion(p_token);

  select id into v_credito_id from creditos where sistema_cliente_id = p_id;
  v_tiene_abonos := v_credito_id is not null and exists (select 1 from abonos where credito_id = v_credito_id);

  update sistemas_cliente set
    cliente_id = p_cliente_id, sistema_id = p_sistema_id, fecha_venta = p_fecha_venta,
    tipo_venta = p_tipo_venta, monto_total = p_monto_total, pago_inicial = p_pago_inicial,
    numero_cuotas = p_numero_cuotas, monto_mensual = p_monto_mensual, fecha_primer_pago = p_fecha_primer_pago
  where id = p_id
  returning * into v_sc;

  if not v_tiene_abonos then
    if v_credito_id is not null then
      delete from cuotas where credito_id = v_credito_id;
      delete from creditos where id = v_credito_id;
    end if;

    update sistemas_cliente set
      periodos_cargados = 0,
      proximo_pago = case when p_tipo_venta = 'suscripcion' then coalesce(p_fecha_primer_pago, p_fecha_venta) end
    where id = p_id;

    if p_tipo_venta = 'mensualidades' and coalesce(p_numero_cuotas, 0) > 0 then
      v_saldo := p_monto_total - coalesce(p_pago_inicial, 0);
      v_fecha_base := coalesce(p_fecha_primer_pago, p_fecha_venta + interval '1 month');
      insert into creditos (cliente_id, origen, sistema_cliente_id, monto_total, saldo_pendiente)
      values (p_cliente_id, 'sistema', p_id, v_saldo, v_saldo)
      returning id into v_credito_id;

      v_monto_cuota := trunc(v_saldo / p_numero_cuotas, 2);
      for i in 1..p_numero_cuotas loop
        insert into cuotas (credito_id, numero, fecha_vencimiento, monto)
        values (
          v_credito_id, i, (v_fecha_base + (interval '1 month' * (i - 1)))::date,
          case when i = p_numero_cuotas then v_saldo - v_monto_cuota * (p_numero_cuotas - 1) else v_monto_cuota end
        );
      end loop;
    elsif p_tipo_venta = 'suscripcion' then
      insert into creditos (cliente_id, origen, sistema_cliente_id, monto_total, saldo_pendiente, notas)
      values (p_cliente_id, 'sistema', p_id, p_monto_mensual, 0, 'Suscripción mensual');
      perform _sincronizar_cargos_suscripcion(p_id);
    end if;
  elsif p_tipo_venta = 'suscripcion' then
    perform _sincronizar_cargos_suscripcion(p_id);
  end if;

  select * into v_sc from sistemas_cliente where id = p_id;
  return v_sc;
end; $$;

-- ============================================================================
-- Lista de cobros: suscripciones activas + primera cuota pendiente de cada credito
-- ============================================================================

create or replace function listar_cobros(p_token uuid)
returns table (
  tipo text, referencia_id uuid, credito_id uuid, cliente_id uuid, cliente_nombre text,
  concepto text, monto numeric, fecha_vencimiento date,
  numero_cuota int, total_cuotas int, saldo_pendiente numeric
)
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  perform generar_cargos_mensuales();
  return query
    select 'suscripcion'::text, sc.id, cr.id, sc.cliente_id, c.nombre_negocio,
           s.nombre, sc.monto_mensual, sc.proximo_pago,
           null::int, null::int, cr.saldo_pendiente
    from sistemas_cliente sc
    join clientes c on c.id = sc.cliente_id
    join sistemas s on s.id = sc.sistema_id
    join creditos cr on cr.sistema_cliente_id = sc.id
    where sc.tipo_venta = 'suscripcion' and sc.activo = true and sc.proximo_pago is not null
    union all
    select 'cuota'::text, q.id, cr.id, cr.cliente_id, c.nombre_negocio,
           coalesce(s.nombre, case cr.origen when 'trabajo' then 'Trabajo' else 'Crédito' end),
           q.monto, q.fecha_vencimiento,
           q.numero, (select count(*)::int from cuotas q2 where q2.credito_id = cr.id), cr.saldo_pendiente
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
-- Marcar pago de una mensualidad de suscripcion (cubre el periodo y avanza un mes)
-- ============================================================================

create or replace function registrar_pago_suscripcion(
  p_token uuid, p_sistema_cliente_id uuid, p_monto numeric default null,
  p_metodo_pago text default null, p_numero_recibo text default null
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

  perform registrar_abono(p_token, v_credito_id, v_monto, 0, p_metodo_pago, p_numero_recibo);

  update sistemas_cliente set
    periodos_cargados = greatest(periodos_cargados - 1, 0),
    proximo_pago = (proximo_pago + interval '1 month')::date
  where id = v_sc.id
  returning * into v_sc;
  return v_sc;
end; $$;

-- ============================================================================
-- Mover la fecha de cobro
-- ============================================================================

create or replace function cambiar_fecha_cobro_suscripcion(
  p_token uuid, p_sistema_cliente_id uuid, p_fecha date
) returns sistemas_cliente
language plpgsql security definer as $$
declare v_sc sistemas_cliente;
begin
  perform _validar_sesion(p_token);
  update sistemas_cliente set proximo_pago = p_fecha
  where id = p_sistema_cliente_id and tipo_venta = 'suscripcion'
  returning * into v_sc;
  if v_sc.id is null then
    raise exception 'Suscripción no encontrada';
  end if;
  perform _sincronizar_cargos_suscripcion(v_sc.id);
  select * into v_sc from sistemas_cliente where id = v_sc.id;
  return v_sc;
end; $$;

-- Mueve la fecha de una cuota; con p_mover_siguientes las cuotas pendientes que le
-- siguen conservan un mes de distancia entre si a partir de la nueva fecha.
create or replace function cambiar_fecha_cuota(
  p_token uuid, p_cuota_id uuid, p_fecha date, p_mover_siguientes boolean default true
) returns void
language plpgsql security definer as $$
declare v_cuota cuotas;
begin
  perform _validar_sesion(p_token);
  select * into v_cuota from cuotas where id = p_cuota_id;
  if v_cuota.id is null then
    raise exception 'Cuota no encontrada';
  end if;
  update cuotas set fecha_vencimiento = p_fecha where id = p_cuota_id;
  if p_mover_siguientes then
    update cuotas set fecha_vencimiento = (p_fecha + (interval '1 month' * (numero - v_cuota.numero)))::date
    where credito_id = v_cuota.credito_id and numero > v_cuota.numero and not pagada;
  end if;
end; $$;
