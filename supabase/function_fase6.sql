-- ==========================================
-- FASE 6: inventario, listado y flujo de caja
-- ==========================================

-- Productos / inventario
create table if not exists productos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  nombre text not null,
  precio_compra numeric(12,2) not null default 0,
  precio_venta numeric(12,2) not null default 0,
  existencias numeric(12,2) not null default 0,
  creado_en timestamptz not null default now(),
  unique (negocio_id, nombre)
);

alter table productos enable row level security;
drop policy if exists "productos de su negocio" on productos;
create policy "productos de su negocio"
  on productos for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());
grant all on productos to anon, authenticated;

-- Seed de inventario de prueba
insert into productos (negocio_id, nombre, precio_compra, precio_venta, existencias)
select id, 'Fruta (caja)', 80, 120, 10 from negocios where nombre = 'Tienda de Doña María'
on conflict (negocio_id, nombre) do nothing;
insert into productos (negocio_id, nombre, precio_compra, precio_venta, existencias)
select id, 'Gaseosa (docena)', 90, 135, 8 from negocios where nombre = 'Tienda de Doña María'
on conflict (negocio_id, nombre) do nothing;
insert into productos (negocio_id, nombre, precio_compra, precio_venta, existencias)
select id, 'Bufanda', 60, 100, 5 from negocios where nombre = 'Tienda de Doña María'
on conflict (negocio_id, nombre) do nothing;

-- Listado de transacciones confirmadas (opcional: filtrar por tipo)
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
  origen text
)
language sql
stable
as $$
  select t.fecha, t.tipo::text, t.monto,
         c1.nombre, c2.nombre,
         coalesce(t.descripcion_original, t.descripcion_normalizada),
         t.origen::text
  from transacciones t
  left join categorias c2 on c2.id = t.categoria_id
  left join categorias c1 on c1.id = c2.categoria_padre_id
  where t.negocio_id = p_negocio_id
    and t.confirmado_por_usuario = true
    and (p_tipo is null or t.tipo = p_tipo::tipo_movimiento)
  order by t.fecha desc, t.creado_en desc
  limit p_limite;
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

-- Inventario (existencias y valor total a precio de compra)
create or replace function obtener_inventario(p_negocio_id uuid)
returns table (
  nombre text,
  precio_compra numeric,
  precio_venta numeric,
  existencias numeric,
  valor_total numeric
)
language sql
stable
as $$
  select nombre, precio_compra, precio_venta, existencias,
         round(coalesce(existencias * precio_compra, 0), 2)
  from productos
  where negocio_id = p_negocio_id
  order by nombre;
$$;

grant execute on function obtener_listado_transacciones(uuid, text, integer) to anon, authenticated;
grant execute on function obtener_flujo_caja(uuid) to anon, authenticated;
grant execute on function obtener_inventario(uuid) to anon, authenticated;
