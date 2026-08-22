-- ==========================================
-- RESET DESDE CERO + LÓGICA DE NEGOCIO (kardex/CPP)
-- Basado en docs/logicanegocio.md
--
-- IMPORTANTE: esto BORRA todas las tablas y datos existentes
-- y recrea el esquema completo. Ejecutar una sola vez.
-- ==========================================

-- ==========================================
-- LIMPIEZA (desde cero)
-- ==========================================
-- Funciones y triggers de scripts anteriores (cambian de firma en este esquema)
drop function if exists obtener_inventario(uuid) cascade;
drop function if exists buscar_o_crear_producto(uuid, text, numeric, numeric, text) cascade;
drop function if exists buscar_o_crear_producto(uuid, text, numeric, numeric, text, text) cascade;
drop function if exists registrar_movimiento_inventario(uuid, text, text, numeric, uuid, numeric, numeric, text) cascade;
drop function if exists obtener_totales_mes(uuid) cascade;
drop function if exists obtener_ultima_transaccion(uuid, text) cascade;
drop function if exists obtener_resumen_analisis(uuid) cascade;
drop function if exists obtener_listado_transacciones(uuid, text, integer) cascade;
drop function if exists obtener_flujo_caja(uuid) cascade;
drop function if exists session_negocio_id() cascade;
drop function if exists chk_tipo_categoria_hijo() cascade;
drop function if exists fn_registrar_compra() cascade;
drop function if exists fn_registrar_produccion() cascade;
drop function if exists fn_registrar_venta_inventario() cascade;

drop view if exists vista_ingresos cascade;
drop view if exists vista_egresos cascade;
drop table if exists conversaciones cascade;
drop table if exists producciones cascade;
drop table if exists compras cascade;
drop table if exists movimientos_inventario cascade;
drop table if exists inventario cascade;
drop table if exists producto_costos cascade;
drop table if exists productos cascade;
drop table if exists transacciones cascade;
drop table if exists inversiones cascade;
drop table if exists prestamos cascade;
drop table if exists categorias cascade;
drop table if exists cuentas_dinero cascade;
drop table if exists usuarios cascade;
drop table if exists negocios cascade;

drop type if exists tipo_movimiento_inventario;
drop type if exists tipo_intencion;
drop type if exists tipo_cuenta_dinero;
drop type if exists origen_transaccion;
drop type if exists tipo_movimiento;

-- ==========================================
-- ENUMS
-- ==========================================
create type tipo_movimiento as enum ('ingreso', 'egreso');
create type origen_transaccion as enum ('voz', 'texto', 'manual');
create type tipo_cuenta_dinero as enum ('efectivo', 'banco', 'digital');
create type tipo_intencion as enum ('conversacional', 'transaccional', 'consulta_reporte');
create type tipo_movimiento_inventario as enum ('compra', 'produccion', 'venta', 'ajuste');

-- ==========================================
-- NEGOCIOS
-- ==========================================
create table negocios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  rubro text,
  regimen_tributario text,
  creado_en timestamptz not null default now()
);

-- ==========================================
-- USUARIOS
-- ==========================================
create table usuarios (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  telefono text,
  rol text not null default 'dueño',
  creado_en timestamptz not null default now()
);

-- ==========================================
-- CUENTAS DE DINERO
-- ==========================================
create table cuentas_dinero (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  nombre text not null,
  tipo tipo_cuenta_dinero not null default 'efectivo',
  saldo_actual numeric(12,2) not null default 0,
  creado_en timestamptz not null default now()
);

-- ==========================================
-- CATEGORIAS (jerárquica 2 niveles)
-- ==========================================
create table categorias (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references negocios(id) on delete cascade, -- null = global
  categoria_padre_id uuid references categorias(id) on delete cascade, -- null = nivel 1
  nombre text not null,
  tipo tipo_movimiento not null,
  creado_en timestamptz not null default now(),
  unique (negocio_id, categoria_padre_id, nombre)
);

create index idx_categorias_negocio on categorias(negocio_id);
create index idx_categorias_padre on categorias(categoria_padre_id);

create or replace function chk_tipo_categoria_hijo()
returns trigger as $$
declare
  tipo_padre tipo_movimiento;
begin
  if new.categoria_padre_id is not null then
    select tipo into tipo_padre from categorias where id = new.categoria_padre_id;
    if tipo_padre is not null and tipo_padre <> new.tipo then
      raise exception 'El tipo de la subcategoría debe coincidir con el de su categoría padre';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_chk_tipo_categoria
before insert or update on categorias
for each row execute function chk_tipo_categoria_hijo();

-- ==========================================
-- PRESTAMOS / INVERSIONES
-- ==========================================
create table prestamos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  entidad_prestamista text,
  monto_total numeric(12,2) not null,
  tasa_interes numeric,
  plazo_meses int,
  saldo_pendiente numeric(12,2) not null,
  fecha_inicio date not null default current_date
);

create table inversiones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  descripcion text not null,
  valor_adquisicion numeric(12,2) not null,
  vida_util_meses int,
  fecha_adquisicion date not null default current_date
);

-- ==========================================
-- PRODUCTOS (catálogo)
-- ==========================================
create table productos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  nombre text not null,
  nombre_normalizado text,
  unidad_medida text not null default 'unidad',
  tipo_producto text not null default 'reventa'
    check (tipo_producto in ('reventa', 'fabricado')),
  precio_compra numeric(12,2) not null default 0,
  precio_venta numeric(12,2) not null default 0,
  stock_minimo numeric(12,2) not null default 0,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  unique (negocio_id, nombre_normalizado)
);

create index idx_productos_negocio on productos(negocio_id);

-- ==========================================
-- TRANSACCIONES (finanzas; congelar costo en ventas)
-- ==========================================
create table transacciones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  cuenta_dinero_id uuid references cuentas_dinero(id),
  categoria_id uuid not null references categorias(id),
  monto numeric(12,2) not null check (monto > 0),
  tipo tipo_movimiento not null,
  producto_id uuid references productos(id), -- producto implicado (venta/compra)
  cantidad numeric(12,2),
  precio_unitario numeric(12,2),
  descripcion_original text,
  descripcion_normalizada text,
  costo_unitario_momento_venta numeric(12,2), -- congelado al vender (CPP vigente)
  utilidad_calculada numeric(12,2),
  fecha date not null default current_date,
  origen origen_transaccion not null default 'texto',
  confianza_clasificacion numeric,
  confirmado_por_usuario boolean not null default false,
  prestamo_id uuid references prestamos(id),
  inversion_id uuid references inversiones(id),
  sincronizado boolean not null default true,
  creado_en timestamptz not null default now()
);

create index idx_transacciones_negocio_fecha on transacciones(negocio_id, fecha);
create index idx_transacciones_categoria on transacciones(categoria_id);
create index idx_transacciones_producto on transacciones(producto_id);

-- ==========================================
-- INVENTARIO: foto actual (única fuente de verdad de existencia y costo)
-- ==========================================
create table inventario (
  producto_id uuid primary key references productos(id) on delete cascade,
  existencia_actual numeric(12,2) not null default 0,
  costo_promedio_actual numeric(12,2) not null default 0,
  valor_inventario numeric(12,2)
    generated always as (existencia_actual * costo_promedio_actual) stored,
  actualizado_en timestamptz not null default now()
);

-- ==========================================
-- KARDEX: historial auditable de cada movimiento (fuente de verdad)
-- ==========================================
create table movimientos_inventario (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references productos(id),
  tipo_movimiento tipo_movimiento_inventario not null,
  cantidad numeric(12,2) not null, -- positivo = entrada, negativo = salida
  costo_unitario numeric(12,2) not null,
  existencia_resultante numeric(12,2) not null,
  costo_promedio_resultante numeric(12,2) not null,
  referencia_compra_id uuid,
  referencia_transaccion_id uuid references transacciones(id),
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

create index idx_mov_inv_producto on movimientos_inventario(producto_id, fecha desc);
create index idx_mov_inv_transaccion on movimientos_inventario(referencia_transaccion_id);

-- ==========================================
-- COMPRAS: entrada de inventario comprado a proveedor
-- ==========================================
create table compras (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  producto_id uuid not null references productos(id),
  proveedor text,
  cantidad numeric(12,2) not null check (cantidad > 0),
  costo_unitario numeric(12,2) not null check (costo_unitario >= 0),
  costo_total numeric(12,2) generated always as (cantidad * costo_unitario) stored,
  transaccion_id uuid references transacciones(id),
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

-- ==========================================
-- PRODUCCIONES: entrada de inventario fabricado con receta
-- ==========================================
create table producciones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  producto_id uuid not null references productos(id),
  cantidad_producida numeric(12,2) not null check (cantidad_producida > 0),
  costo_total_lote numeric(12,2) not null,
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

-- ==========================================
-- PRODUCTO_COSTOS: receta de insumos (solo para productos fabricados)
-- ==========================================
create table producto_costos (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references productos(id) on delete cascade,
  descripcion text not null,
  costo numeric(12,2) not null check (costo >= 0),
  creado_en timestamptz not null default now()
);

-- ==========================================
-- CONVERSACIONES (log de cada interacción)
-- ==========================================
create table conversaciones (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references usuarios(id) on delete cascade,
  mensaje_usuario text not null,
  intencion_detectada tipo_intencion not null,
  respuesta_sistema text,
  transaccion_id uuid references transacciones(id),
  creado_en timestamptz not null default now()
);

-- ==========================================
-- VISTAS
-- ==========================================
create view vista_ingresos as
  select * from transacciones where tipo = 'ingreso';
create view vista_egresos as
  select * from transacciones where tipo = 'egreso';

-- ==========================================
-- TRIGGERS: inventario automático (CPP)
-- ==========================================

-- Registrar una COMPRA (entrada de inventario comprado)
create or replace function fn_registrar_compra()
returns trigger as $$
declare
  inv record;
  nueva_existencia numeric;
  nuevo_costo_prom numeric;
begin
  select * into inv from inventario where producto_id = new.producto_id for update;
  if not found then
    insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
      values (new.producto_id, 0, 0);
    select * into inv from inventario where producto_id = new.producto_id for update;
  end if;

  nueva_existencia := inv.existencia_actual + new.cantidad;
  nuevo_costo_prom := round(
    (inv.existencia_actual * inv.costo_promedio_actual
     + new.cantidad * new.costo_unitario) / nueva_existencia, 2);

  update inventario
    set existencia_actual = nueva_existencia,
        costo_promedio_actual = nuevo_costo_prom,
        actualizado_en = now()
    where producto_id = new.producto_id;

  insert into movimientos_inventario
    (producto_id, tipo_movimiento, cantidad, costo_unitario,
     existencia_resultante, costo_promedio_resultante,
     referencia_compra_id, fecha)
  values
    (new.producto_id, 'compra', new.cantidad, new.costo_unitario,
     nueva_existencia, nuevo_costo_prom, new.id, new.fecha);

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_registrar_compra on compras;
create trigger trg_registrar_compra
after insert on compras
for each row execute function fn_registrar_compra();

-- Registrar una PRODUCCIÓN (entrada de inventario fabricado)
create or replace function fn_registrar_produccion()
returns trigger as $$
declare
  inv record;
  nueva_existencia numeric;
  costo_unit numeric;
  nuevo_costo_prom numeric;
begin
  costo_unit := round(new.costo_total_lote / new.cantidad_producida, 2);

  select * into inv from inventario where producto_id = new.producto_id for update;
  if not found then
    insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
      values (new.producto_id, 0, 0);
    select * into inv from inventario where producto_id = new.producto_id for update;
  end if;

  nueva_existencia := inv.existencia_actual + new.cantidad_producida;
  nuevo_costo_prom := round(
    (inv.existencia_actual * inv.costo_promedio_actual
     + new.cantidad_producida * costo_unit) / nueva_existencia, 2);

  update inventario
    set existencia_actual = nueva_existencia,
        costo_promedio_actual = nuevo_costo_prom,
        actualizado_en = now()
    where producto_id = new.producto_id;

  insert into movimientos_inventario
    (producto_id, tipo_movimiento, cantidad, costo_unitario,
     existencia_resultante, costo_promedio_resultante, fecha)
  values
    (new.producto_id, 'produccion', new.cantidad_producida, costo_unit,
     nueva_existencia, nuevo_costo_prom, new.fecha);

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_registrar_produccion on producciones;
create trigger trg_registrar_produccion
after insert on producciones
for each row execute function fn_registrar_produccion();

-- Registrar una VENTA (salida de inventario + utilidad real con costo congelado)
create or replace function fn_registrar_venta_inventario()
returns trigger as $$
declare
  inv record;
  nueva_existencia numeric;
begin
  -- Bandera de sesión para evitar recursión (el update interno re-dispara).
  if current_setting('app.procesando_venta', true) = '1' then
    return new;
  end if;

  if new.tipo = 'ingreso' and new.producto_id is not null
     and new.cantidad is not null and new.cantidad > 0 then

    perform set_config('app.procesando_venta', '1', true);

    -- Limpiar un movimiento previo si la venta se re-procesa
    delete from movimientos_inventario
      where referencia_transaccion_id = new.id and tipo_movimiento = 'venta';

    select * into inv from inventario where producto_id = new.producto_id for update;
    if not found then
      insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
        values (new.producto_id, 0, 0);
      select * into inv from inventario where producto_id = new.producto_id for update;
    end if;

    nueva_existencia := inv.existencia_actual - new.cantidad;

    update transacciones
      set costo_unitario_momento_venta = inv.costo_promedio_actual,
          utilidad_calculada = round(new.monto - inv.costo_promedio_actual * new.cantidad, 2)
      where id = new.id;

    update inventario
      set existencia_actual = nueva_existencia,
          actualizado_en = now()
      where producto_id = new.producto_id;

    insert into movimientos_inventario
      (producto_id, tipo_movimiento, cantidad, costo_unitario,
       existencia_resultante, costo_promedio_resultante,
       referencia_transaccion_id, fecha)
    values
      (new.producto_id, 'venta', -new.cantidad, inv.costo_promedio_actual,
       nueva_existencia, inv.costo_promedio_actual, new.id, new.fecha);

    perform set_config('app.procesando_venta', '0', true);
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_registrar_venta_inventario on transacciones;
create trigger trg_registrar_venta_inventario
after insert or update on transacciones
for each row execute function fn_registrar_venta_inventario();

-- ==========================================
-- RPCs usados por la app
-- ==========================================

-- Busca o crea un producto dentro del negocio
create or replace function buscar_o_crear_producto(
  p_negocio_id uuid,
  p_nombre text,
  p_precio_compra numeric default null,
  p_precio_venta numeric default null,
  p_unidad_medida text default 'unidad',
  p_tipo_producto text default 'reventa'
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_nombre text := nullif(trim(p_nombre), '');
  v_normalizado text := lower(nullif(trim(p_nombre), ''));
  v_id uuid;
begin
  if v_nombre is null then
    raise exception 'El nombre del producto es requerido';
  end if;

  select id into v_id
  from productos
  where negocio_id = p_negocio_id
    and nombre_normalizado = v_normalizado
  limit 1;

  if v_id is not null then
    update productos
    set precio_compra = coalesce(p_precio_compra, precio_compra),
        precio_venta = coalesce(p_precio_venta, precio_venta),
        unidad_medida = coalesce(nullif(trim(p_unidad_medida), ''), unidad_medida),
        tipo_producto = coalesce(nullif(trim(p_tipo_producto), ''), tipo_producto),
        activo = true
    where id = v_id;
    return v_id;
  end if;

  insert into productos (
    negocio_id, nombre, nombre_normalizado,
    unidad_medida, tipo_producto,
    precio_compra, precio_venta
  ) values (
    p_negocio_id, v_nombre, v_normalizado,
    coalesce(nullif(trim(p_unidad_medida), ''), 'unidad'),
    coalesce(nullif(trim(p_tipo_producto), ''), 'reventa'),
    coalesce(p_precio_compra, 0),
    coalesce(p_precio_venta, 0)
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Inventario actual (existencias, costo promedio, valor, utilidad y estado)
create or replace function obtener_inventario(p_negocio_id uuid)
returns table (
  nombre text,
  precio_compra numeric,
  precio_venta numeric,
  existencias numeric,
  costo_promedio numeric,
  valor_total numeric,
  utilidad_unitaria numeric,
  stock_minimo numeric,
  estado text
)
language sql
stable
as $$
  select p.nombre,
         p.precio_compra,
         p.precio_venta,
         coalesce(i.existencia_actual, 0),
         coalesce(i.costo_promedio_actual, 0),
         coalesce(i.valor_inventario, 0),
         round(coalesce(p.precio_venta, 0) - coalesce(i.costo_promedio_actual, 0), 2),
         p.stock_minimo,
         case
           when coalesce(i.existencia_actual, 0) <= 0 then 'agotado'
           when coalesce(i.existencia_actual, 0) <= p.stock_minimo then 'bajo'
           else 'ok'
         end as estado
  from productos p
  left join inventario i on i.producto_id = p.id
  where p.negocio_id = p_negocio_id
    and p.activo = true
  order by p.nombre;
$$;

-- Totales del mes actual
create or replace function obtener_totales_mes(p_negocio_id uuid)
returns table (
  ingresos numeric,
  egresos numeric,
  cantidad_ingresos bigint,
  cantidad_egresos bigint
)
language sql
stable
as $$
  select
    coalesce(sum(monto) filter (where tipo = 'ingreso'), 0)::numeric,
    coalesce(sum(monto) filter (where tipo = 'egreso'), 0)::numeric,
    count(*) filter (where tipo = 'ingreso'),
    count(*) filter (where tipo = 'egreso')
  from transacciones
  where negocio_id = p_negocio_id
    and confirmado_por_usuario = true
    and fecha >= date_trunc('month', current_date)
    and fecha < date_trunc('month', current_date) + interval '1 month';
$$;

-- Última transacción confirmada
create or replace function obtener_ultima_transaccion(
  p_negocio_id uuid,
  p_tipo text default null
)
returns jsonb
language sql
stable
as $$
  select to_jsonb(t)
  from (
    select t.monto, t.tipo, t.fecha, t.descripcion_normalizada,
           c1.nombre as categoria_nivel1,
           c2.nombre as categoria_nivel2
    from transacciones t
    left join categorias c2 on c2.id = t.categoria_id
    left join categorias c1 on c1.id = c2.categoria_padre_id
    where t.negocio_id = p_negocio_id
      and t.confirmado_por_usuario = true
      and (p_tipo is null or t.tipo = p_tipo::tipo_movimiento)
    order by t.fecha desc, t.creado_en desc
    limit 1
  ) t;
$$;

-- Resumen del mes: totales + desglose por categoría
create or replace function obtener_resumen_analisis(p_negocio_id uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'ingresos', coalesce(sum(monto) filter (where tipo = 'ingreso'), 0),
    'egresos', coalesce(sum(monto) filter (where tipo = 'egreso'), 0),
    'cantidad_ingresos', count(*) filter (where tipo = 'ingreso'),
    'cantidad_egresos', count(*) filter (where tipo = 'egreso'),
    'por_categoria', coalesce((
      select jsonb_agg(row_to_json(c))
      from (
        select c1.nombre as categoria_nivel1,
               c2.nombre as categoria_nivel2,
               t.tipo,
               sum(t.monto) as total,
               count(*) as cantidad
        from transacciones t
        left join categorias c2 on c2.id = t.categoria_id
        left join categorias c1 on c1.id = c2.categoria_padre_id
        where t.negocio_id = p_negocio_id
          and t.confirmado_por_usuario = true
          and t.fecha >= date_trunc('month', current_date)
          and t.fecha < date_trunc('month', current_date) + interval '1 month'
        group by c1.nombre, c2.nombre, t.tipo
        order by total desc
      ) c
    ), '[]'::jsonb)
  )
  from transacciones
  where negocio_id = p_negocio_id
    and confirmado_por_usuario = true
    and fecha >= date_trunc('month', current_date)
    and fecha < date_trunc('month', current_date) + interval '1 month';
$$;

-- Listado de transacciones confirmadas (con desglose y utilidad en ventas)
create or replace function obtener_listado_transacciones(
  p_negocio_id uuid,
  p_tipo text default null,
  p_limite integer default 50
)
returns table (
  fecha date,
  tipo text,
  monto numeric,
  categoria_nivel1 text,
  categoria_nivel2 text,
  descripcion text,
  origen text,
  cantidad numeric,
  precio_unitario numeric,
  costo_unitario_momento_venta numeric,
  utilidad_calculada numeric
)
language sql
stable
as $$
  select t.fecha, t.tipo::text, t.monto,
         c1.nombre, c2.nombre,
         coalesce(t.descripcion_normalizada, t.descripcion_original),
         t.origen::text,
         t.cantidad, t.precio_unitario,
         t.costo_unitario_momento_venta, t.utilidad_calculada
  from transacciones t
  left join categorias c2 on c2.id = t.categoria_id
  left join categorias c1 on c1.id = c2.categoria_padre_id
  where t.negocio_id = p_negocio_id
    and t.confirmado_por_usuario = true
    and (p_tipo is null or t.tipo = p_tipo::tipo_movimiento)
  order by t.fecha desc, t.creado_en desc
  limit p_limite;
$$;

-- Resumen de ganancia del mes: ingresos, costo de venta, utilidad y margen
create or replace function obtener_resumen_ganancias(p_negocio_id uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'ingresos', coalesce(sum(monto) filter (where tipo = 'ingreso'), 0),
    'costo_ventas', coalesce(sum(
        case when tipo = 'ingreso' then costo_unitario_momento_venta * coalesce(cantidad, 0) else 0 end
      ), 0),
    'utilidad', coalesce(sum(
        case when tipo = 'ingreso' and costo_unitario_momento_venta is not null then utilidad_calculada else 0 end
      ), 0),
    'cantidad_ventas', count(*) filter (where tipo = 'ingreso' and costo_unitario_momento_venta is not null),
    'margen', round(
        case
          when sum(monto) filter (where tipo = 'ingreso') > 0
          then coalesce(sum(
            case when tipo = 'ingreso' and costo_unitario_momento_venta is not null then utilidad_calculada else 0 end
          ), 0) / sum(monto) filter (where tipo = 'ingreso')
          else 0
        end, 4)
  )
  from transacciones
  where negocio_id = p_negocio_id
    and confirmado_por_usuario = true
    and fecha >= date_trunc('month', current_date)
    and fecha < date_trunc('month', current_date) + interval '1 month';
$$;

-- Flujo de caja diario del mes actual
create or replace function obtener_flujo_caja(p_negocio_id uuid)
returns table (fecha date, ingresos numeric, egresos numeric, balance numeric)
language sql
stable
as $$
  select fecha,
         coalesce(sum(monto) filter (where tipo = 'ingreso'), 0),
         coalesce(sum(monto) filter (where tipo = 'egreso'), 0),
         coalesce(sum(monto) filter (where tipo = 'ingreso'), 0)
           - coalesce(sum(monto) filter (where tipo = 'egreso'), 0)
  from transacciones
  where negocio_id = p_negocio_id
    and confirmado_por_usuario = true
    and fecha >= date_trunc('month', current_date)
    and fecha < date_trunc('month', current_date) + interval '1 month'
  group by fecha
  order by fecha desc;
$$;

grant execute on function buscar_o_crear_producto(uuid, text, numeric, numeric, text, text)
  to anon, authenticated;
grant execute on function obtener_inventario(uuid) to anon, authenticated;
grant execute on function obtener_totales_mes(uuid) to anon, authenticated;
grant execute on function obtener_ultima_transaccion(uuid, text) to anon, authenticated;
grant execute on function obtener_resumen_analisis(uuid) to anon, authenticated;
grant execute on function obtener_listado_transacciones(uuid, text, integer) to anon, authenticated;
grant execute on function obtener_resumen_ganancias(uuid) to anon, authenticated;
grant execute on function obtener_flujo_caja(uuid) to anon, authenticated;

-- ==========================================
-- ROW LEVEL SECURITY
-- ==========================================
create or replace function session_negocio_id()
returns uuid
language sql
stable
as $$
  select (current_setting('request.headers', true)::jsonb ->> 'x-negocio-id')::uuid
$$;

alter table negocios enable row level security;
create policy "negocios lectura anon"
  on negocios for select to anon, authenticated
  using (true);

alter table usuarios enable row level security;
create policy "usuarios de su negocio"
  on usuarios for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table cuentas_dinero enable row level security;
create policy "cuentas de su negocio"
  on cuentas_dinero for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table categorias enable row level security;
create policy "categorias globales y de su negocio"
  on categorias for all to anon, authenticated
  using (negocio_id is null or negocio_id = session_negocio_id())
  with check (negocio_id is null or negocio_id = session_negocio_id());

alter table prestamos enable row level security;
create policy "prestamos de su negocio"
  on prestamos for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table inversiones enable row level security;
create policy "inversiones de su negocio"
  on inversiones for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table transacciones enable row level security;
create policy "transacciones de su negocio"
  on transacciones for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table productos enable row level security;
create policy "productos de su negocio"
  on productos for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table inventario enable row level security;
create policy "inventario de su negocio"
  on inventario for all to anon, authenticated
  using (
    exists (
      select 1 from productos p
      where p.id = inventario.producto_id
        and p.negocio_id = session_negocio_id()
    )
  )
  with check (
    exists (
      select 1 from productos p
      where p.id = inventario.producto_id
        and p.negocio_id = session_negocio_id()
    )
  );

alter table movimientos_inventario enable row level security;
create policy "movimientos de su negocio"
  on movimientos_inventario for all to anon, authenticated
  using (
    exists (
      select 1 from productos p
      where p.id = movimientos_inventario.producto_id
        and p.negocio_id = session_negocio_id()
    )
  )
  with check (
    exists (
      select 1 from productos p
      where p.id = movimientos_inventario.producto_id
        and p.negocio_id = session_negocio_id()
    )
  );

alter table compras enable row level security;
create policy "compras de su negocio"
  on compras for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table producciones enable row level security;
create policy "producciones de su negocio"
  on producciones for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

alter table producto_costos enable row level security;
create policy "producto costos de su negocio"
  on producto_costos for all to anon, authenticated
  using (
    exists (
      select 1 from productos p
      where p.id = producto_costos.producto_id
        and p.negocio_id = session_negocio_id()
    )
  )
  with check (
    exists (
      select 1 from productos p
      where p.id = producto_costos.producto_id
        and p.negocio_id = session_negocio_id()
    )
  );

alter table conversaciones enable row level security;
create policy "conversaciones de su negocio"
  on conversaciones for all to anon, authenticated
  using (
    exists (
      select 1 from usuarios u
      where u.id = conversaciones.usuario_id
        and u.negocio_id = session_negocio_id()
    )
  )
  with check (
    exists (
      select 1 from usuarios u
      where u.id = conversaciones.usuario_id
        and u.negocio_id = session_negocio_id()
    )
  );

grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;

-- ==========================================
-- SEED: datos base necesarios (desde cero)
-- 8 categorías de nivel 1 + negocio/usuario/cuenta de prueba
-- ==========================================
insert into categorias (nombre, tipo, categoria_padre_id, negocio_id) values
  ('Ingresos', 'ingreso', null, null),
  ('Costos de venta', 'egreso', null, null),
  ('Gastos operativos', 'egreso', null, null),
  ('Gastos administrativos', 'egreso', null, null),
  ('Otros gastos', 'egreso', null, null),
  ('Inversiones', 'egreso', null, null),
  ('Préstamos y financiamiento', 'egreso', null, null),
  ('Retiros personales', 'egreso', null, null);

insert into negocios (nombre, rubro, regimen_tributario) values
  ('Tienda de Doña María', 'tienda de abarrotes', 'pequeño contribuyente');

insert into usuarios (negocio_id, telefono, rol)
select id, '50200000000', 'dueño'
from negocios
where nombre = 'Tienda de Doña María';

insert into cuentas_dinero (negocio_id, nombre, tipo, saldo_actual)
select id, 'Efectivo', 'efectivo', 0
from negocios
where nombre = 'Tienda de Doña María';
