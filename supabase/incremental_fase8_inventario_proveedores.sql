-- ============================================================================
-- FASE 8 INCREMENTAL: INVENTARIO ENRIQUECIDO, PROVEEDORES Y OPERACIONES DE STOCK
-- NO borra datos existentes. Es 100% incremental y compatible.
-- ============================================================================

-- 1. TABLA DE PROVEEDORES
create table if not exists proveedores (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  nombre text not null,
  contacto text,
  telefono text,
  direccion text,
  dias_visita text,
  notas text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists idx_proveedores_negocio on proveedores(negocio_id);

-- RLS para proveedores
alter table proveedores enable row level security;

drop policy if exists "proveedores de su negocio" on proveedores;
create policy "proveedores de su negocio"
  on proveedores for all to anon, authenticated
  using (negocio_id = session_negocio_id() or session_negocio_id() is null)
  with check (negocio_id = session_negocio_id() or session_negocio_id() is null);

-- 2. AMPLIAR TABLA PRODUCTOS CON NUEVOS ATRIBUTOS
alter table productos
  add column if not exists imagen_url text,
  add column if not exists codigo_barras text,
  add column if not exists categoria_producto text,
  add column if not exists stock_maximo numeric(12,2) default null,
  add column if not exists proveedor_id uuid references proveedores(id) on delete set null;

create index if not exists idx_productos_proveedor on productos(proveedor_id);
create index if not exists idx_productos_codigo on productos(negocio_id, codigo_barras);

-- 3. AMPLIAR COMPRAS CON PROVEEDOR_ID
alter table compras
  add column if not exists proveedor_id uuid references proveedores(id) on delete set null;

-- 4. AMPLIAR MOVIMIENTOS_INVENTARIO CON MOTIVO DE AJUSTE
alter table movimientos_inventario
  add column if not exists motivo text;

-- 5. RPC: OBTENER_INVENTARIO_V2 (Retorna id, imagen, categoría, unidad, proveedor y cálculo completo)
drop function if exists obtener_inventario(uuid);
create or replace function obtener_inventario(p_negocio_id uuid)
returns table (
  id uuid,
  nombre text,
  imagen_url text,
  codigo_barras text,
  categoria_producto text,
  unidad_medida text,
  precio_compra numeric,
  precio_venta numeric,
  existencias numeric,
  costo_promedio numeric,
  valor_total numeric,
  utilidad_unitaria numeric,
  stock_minimo numeric,
  stock_maximo numeric,
  proveedor_id uuid,
  proveedor_nombre text,
  estado text
)
language sql
stable
as $$
  select p.id,
         p.nombre,
         p.imagen_url,
         p.codigo_barras,
         p.categoria_producto,
         p.unidad_medida,
         p.precio_compra,
         p.precio_venta,
         coalesce(i.existencia_actual, 0) as existencias,
         coalesce(i.costo_promedio_actual, 0) as costo_promedio,
         coalesce(i.valor_inventario, 0) as valor_total,
         round(coalesce(p.precio_venta, 0) - coalesce(i.costo_promedio_actual, 0), 2) as utilidad_unitaria,
         p.stock_minimo,
         p.stock_maximo,
         p.proveedor_id,
         prov.nombre as proveedor_nombre,
         case
           when coalesce(i.existencia_actual, 0) <= 0 then 'agotado'
           when coalesce(i.existencia_actual, 0) <= p.stock_minimo then 'bajo'
           else 'ok'
         end as estado
  from productos p
  left join inventario i on i.producto_id = p.id
  left join proveedores prov on prov.id = p.proveedor_id
  where p.negocio_id = p_negocio_id
    and p.activo = true
  order by p.nombre;
$$;

-- 6. RPC: ACTUALIZAR PRODUCTO POR ID (Permite cambiar el nombre sin romper registros)
create or replace function actualizar_producto_por_id(
  p_negocio_id uuid,
  p_producto_id uuid,
  p_nuevo_nombre text default null,
  p_precio_venta numeric default null,
  p_precio_compra numeric default null,
  p_stock_minimo numeric default null,
  p_stock_maximo numeric default null,
  p_unidad_medida text default null,
  p_categoria_producto text default null,
  p_codigo_barras text default null,
  p_imagen_url text default null,
  p_proveedor_id uuid default null
)
returns boolean
language plpgsql
security definer
as $$
declare
  v_nuevo_nombre_limpio text := nullif(trim(p_nuevo_nombre), '');
  v_nuevo_norm text := lower(v_nuevo_nombre_limpio);
  v_actualizado integer;
begin
  update productos
  set nombre = coalesce(v_nuevo_nombre_limpio, nombre),
      nombre_normalizado = coalesce(v_nuevo_norm, nombre_normalizado),
      precio_venta = coalesce(p_precio_venta, precio_venta),
      precio_compra = coalesce(p_precio_compra, precio_compra),
      stock_minimo = coalesce(p_stock_minimo, stock_minimo),
      stock_maximo = coalesce(p_stock_maximo, stock_maximo),
      unidad_medida = coalesce(nullif(trim(p_unidad_medida), ''), unidad_medida),
      categoria_producto = coalesce(nullif(trim(p_categoria_producto), ''), categoria_producto),
      codigo_barras = coalesce(nullif(trim(p_codigo_barras), ''), codigo_barras),
      imagen_url = coalesce(p_imagen_url, imagen_url),
      proveedor_id = coalesce(p_proveedor_id, proveedor_id),
      activo = true
  where id = p_producto_id
    and negocio_id = p_negocio_id;

  get diagnostics v_actualizado = row_count;
  return v_actualizado > 0;
end;
$$;

-- 7. RPC: AJUSTAR INVENTARIO CON MOTIVO
create or replace function ajustar_inventario_con_motivo(
  p_negocio_id uuid,
  p_producto_id uuid,
  p_cantidad_objetivo numeric,
  p_motivo text default 'Ajuste manual'
)
returns boolean
language plpgsql
security definer
as $$
declare
  v_existencia_actual numeric;
  v_costo_promedio numeric;
  v_delta numeric;
begin
  if p_cantidad_objetivo is null or p_cantidad_objetivo < 0 then
    raise exception 'La cantidad objetivo debe ser mayor o igual a cero';
  end if;

  select coalesce(existencia_actual, 0), coalesce(costo_promedio_actual, 0)
  into v_existencia_actual, v_costo_promedio
  from inventario
  where producto_id = p_producto_id;

  if not found then
    v_existencia_actual := 0;
    v_costo_promedio := 0;
  end if;

  v_delta := p_cantidad_objetivo - v_existencia_actual;

  if v_delta <> 0 then
    insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
    values (p_producto_id, p_cantidad_objetivo, v_costo_promedio)
    on conflict (producto_id)
    do update set existencia_actual = excluded.existencia_actual,
                  actualizado_en = now();

    insert into movimientos_inventario (
      producto_id, tipo_movimiento, cantidad, costo_unitario,
      existencia_resultante, costo_promedio_resultante, motivo, fecha
    ) values (
      p_producto_id, 'ajuste', v_delta, v_costo_promedio,
      p_cantidad_objetivo, v_costo_promedio, coalesce(p_motivo, 'Ajuste manual'), current_date
    );
  end if;

  return true;
end;
$$;

-- 8. RPC: OBTENER KARDEX POR PRODUCTO
create or replace function obtener_kardex_producto(
  p_producto_id uuid,
  p_limite integer default 30
)
returns table (
  id uuid,
  tipo_movimiento text,
  cantidad numeric,
  costo_unitario numeric,
  existencia_resultante numeric,
  costo_promedio_resultante numeric,
  motivo text,
  fecha date,
  creado_en timestamptz
)
language sql
stable
as $$
  select id,
         tipo_movimiento::text,
         cantidad,
         costo_unitario,
         existencia_resultante,
         costo_promedio_resultante,
         motivo,
         fecha,
         creado_en
  from movimientos_inventario
  where producto_id = p_producto_id
  order by creado_en desc
  limit coalesce(p_limite, 30);
$$;

-- Permisos
grant execute on function obtener_inventario(uuid) to anon, authenticated;
grant execute on function actualizar_producto_por_id(uuid, uuid, text, numeric, numeric, numeric, numeric, text, text, text, text, uuid) to anon, authenticated;
grant execute on function ajustar_inventario_con_motivo(uuid, uuid, numeric, text) to anon, authenticated;
grant execute on function obtener_kardex_producto(uuid, integer) to anon, authenticated;
