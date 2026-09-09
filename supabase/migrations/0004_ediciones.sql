-- Permite editar lo ya creado (sistemas vendidos, trabajos, creditos manuales) y
-- controlar la fecha del primer pago al vender un sistema a mensualidades o suscripcion,
-- en vez de asumir siempre "un mes despues de la venta".

alter table sistemas_cliente add column if not exists fecha_primer_pago date;

-- ============================================================================
-- SISTEMAS_CLIENTE: fecha_primer_pago + edicion
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
  insert into sistemas_cliente (cliente_id, sistema_id, fecha_venta, tipo_venta, monto_total, pago_inicial, numero_cuotas, monto_mensual, fecha_primer_pago)
  values (p_cliente_id, p_sistema_id, p_fecha_venta, p_tipo_venta, p_monto_total, p_pago_inicial, p_numero_cuotas, p_monto_mensual, p_fecha_primer_pago)
  returning * into v_sc;
  return v_sc;
end; $$;

create or replace function trg_crear_credito_sistema() returns trigger
language plpgsql as $$
declare
  v_saldo numeric;
  v_monto_cuota numeric;
  v_credito_id uuid;
  v_fecha_base date;
  i int;
begin
  if new.tipo_venta = 'mensualidades' and coalesce(new.numero_cuotas, 0) > 0 then
    v_saldo := new.monto_total - coalesce(new.pago_inicial, 0);
    v_fecha_base := coalesce(new.fecha_primer_pago, new.fecha_venta + interval '1 month');
    insert into creditos (cliente_id, origen, sistema_cliente_id, monto_total, saldo_pendiente)
    values (new.cliente_id, 'sistema', new.id, v_saldo, v_saldo)
    returning id into v_credito_id;

    v_monto_cuota := trunc(v_saldo / new.numero_cuotas, 2);
    for i in 1..new.numero_cuotas loop
      insert into cuotas (credito_id, numero, fecha_vencimiento, monto)
      values (
        v_credito_id, i, (v_fecha_base + (interval '1 month' * (i - 1)))::date,
        case when i = new.numero_cuotas
          then v_saldo - v_monto_cuota * (new.numero_cuotas - 1)
          else v_monto_cuota
        end
      );
    end loop;
  elsif new.tipo_venta = 'suscripcion' then
    insert into creditos (cliente_id, origen, sistema_cliente_id, monto_total, saldo_pendiente, notas)
    values (new.cliente_id, 'sistema', new.id, new.monto_mensual, 0, 'Suscripción mensual');
  end if;
  return new;
end; $$;

-- generar_cargos_mensuales: no cobra suscripciones antes de su fecha de primer pago
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
      and (sc.fecha_primer_pago is null or sc.fecha_primer_pago <= current_date)
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

-- listar_sistemas_cliente: agrega fecha_primer_pago a la salida
create or replace function listar_sistemas_cliente(p_token uuid, p_cliente_id uuid default null)
returns table (
  id uuid, cliente_id uuid, sistema_id uuid, sistema_nombre text, sistema_slug text,
  fecha_venta date, tipo_venta text, monto_total numeric, pago_inicial numeric,
  numero_cuotas int, monto_mensual numeric, fecha_primer_pago date, activo boolean
)
language plpgsql security definer as $$
begin
  perform _validar_sesion(p_token);
  return query
    select sc.id, sc.cliente_id, sc.sistema_id, s.nombre, s.slug,
           sc.fecha_venta, sc.tipo_venta, sc.monto_total, sc.pago_inicial,
           sc.numero_cuotas, sc.monto_mensual, sc.fecha_primer_pago, sc.activo
    from sistemas_cliente sc
    join sistemas s on s.id = sc.sistema_id
    where p_cliente_id is null or sc.cliente_id = p_cliente_id
    order by sc.fecha_venta desc;
end; $$;

-- Edita una venta ya creada. Si su credito todavia no tiene abonos, se regenera
-- por completo (credito + cuotas) con los valores nuevos; si ya tiene abonos,
-- solo se actualizan los datos de la venta (no se toca el saldo/cuotas ya en curso).
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
    end if;
  end if;

  return v_sc;
end; $$;

-- ============================================================================
-- TRABAJOS: edicion
-- ============================================================================

create or replace function actualizar_trabajo(
  p_token uuid, p_id uuid, p_descripcion text, p_fecha date, p_monto numeric
) returns trabajos
language plpgsql security definer as $$
declare
  v_trabajo trabajos;
  v_credito creditos;
begin
  perform _validar_sesion(p_token);

  update trabajos set descripcion = p_descripcion, fecha = p_fecha, monto = p_monto
  where id = p_id
  returning * into v_trabajo;

  select * into v_credito from creditos where trabajo_id = p_id;
  if v_credito.id is not null and not exists (select 1 from abonos where credito_id = v_credito.id) then
    update creditos set monto_total = p_monto, saldo_pendiente = p_monto where id = v_credito.id;
  end if;

  return v_trabajo;
end; $$;

-- ============================================================================
-- CREDITOS MANUALES: edicion (solo origen = 'manual')
-- ============================================================================

create or replace function actualizar_credito_manual(
  p_token uuid, p_id uuid, p_monto_total numeric, p_fecha_vencimiento date default null, p_notas text default null
) returns creditos
language plpgsql security definer as $$
declare
  v_credito creditos;
  v_abonado numeric;
begin
  perform _validar_sesion(p_token);
  select coalesce(sum(monto_abonado), 0) into v_abonado from abonos where credito_id = p_id;

  update creditos set
    monto_total = p_monto_total,
    saldo_pendiente = greatest(p_monto_total - v_abonado, 0),
    fecha_vencimiento = p_fecha_vencimiento,
    notas = p_notas
  where id = p_id and origen = 'manual'
  returning * into v_credito;

  if v_credito.id is null then
    raise exception 'Crédito no encontrado o no es editable (no es manual)';
  end if;
  return v_credito;
end; $$;

-- ============================================================================
-- REPORTES DE FALLOS: permite editar tambien la descripcion
-- ============================================================================

create or replace function actualizar_reporte_fallo(
  p_token uuid, p_id uuid, p_estado text default null,
  p_cobrado boolean default null, p_monto_cobrado numeric default null,
  p_descripcion text default null
) returns reportes_fallos
language plpgsql security definer as $$
declare v_reporte reportes_fallos;
begin
  perform _validar_sesion(p_token);
  update reportes_fallos set
    estado = coalesce(p_estado, estado),
    cobrado = coalesce(p_cobrado, cobrado),
    monto_cobrado = coalesce(p_monto_cobrado, monto_cobrado),
    descripcion = coalesce(p_descripcion, descripcion),
    fecha_resolucion = case when p_estado = 'resuelto' then now() else fecha_resolucion end
  where id = p_id
  returning * into v_reporte;
  return v_reporte;
end; $$;
