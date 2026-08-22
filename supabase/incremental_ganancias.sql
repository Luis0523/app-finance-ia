-- ==========================================
-- INCREMENTAL: ganancia en inventario, listado y resumen
-- NO borra datos. Solo agrega/actualiza funciones.
-- ==========================================

-- 1. Inventario: agregar costo_promedio y utilidad_unitaria
drop function if exists obtener_inventario(uuid);
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

-- 2. Listado: agregar costo congelado y utilidad en ventas
drop function if exists obtener_listado_transacciones(uuid, text, integer);
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

-- 3. Resumen de ganancia del mes
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

grant execute on function obtener_inventario(uuid) to anon, authenticated;
grant execute on function obtener_listado_transacciones(uuid, text, integer) to anon, authenticated;
grant execute on function obtener_resumen_ganancias(uuid) to anon, authenticated;
