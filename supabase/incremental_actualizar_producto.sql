-- ==========================================
-- INCREMENTAL: actualizar producto + ajuste de inventario
-- NO borra datos. Agrega RPCs.
-- ==========================================

-- Actualiza precio de venta, precio de compra y/o stock mínimo de un producto.
-- Busca por nombre normalizado dentro del negocio.
create or replace function actualizar_producto(
  p_negocio_id uuid,
  p_nombre text,
  p_precio_venta numeric default null,
  p_precio_compra numeric default null,
  p_stock_minimo numeric default null
)
returns boolean
language plpgsql
security definer
as $$
declare
  v_normalizado text := lower(nullif(trim(p_nombre), ''));
  v_actualizado integer;
begin
  if v_normalizado is null then
    raise exception 'El nombre del producto es requerido';
  end if;

  update productos
  set precio_venta = coalesce(p_precio_venta, precio_venta),
      precio_compra = coalesce(p_precio_compra, precio_compra),
      stock_minimo = coalesce(p_stock_minimo, stock_minimo),
      activo = true
  where negocio_id = p_negocio_id
    and nombre_normalizado = v_normalizado;

  get diagnostics v_actualizado = row_count;
  return v_actualizado > 0;
end;
$$;

-- Ajusta la existencia de un producto a una cantidad objetivo.
-- Registra un movimiento tipo 'ajuste' (a costo promedio vigente) y actualiza
-- la foto de inventario. Usa el costo promedio actual si existe, si no, 0.
create or replace function ajustar_inventario(
  p_negocio_id uuid,
  p_nombre text,
  p_cantidad_objetivo numeric
)
returns boolean
language plpgsql
security definer
as $$
declare
  v_producto_id uuid;
  v_existencia_actual numeric;
  v_costo_promedio numeric;
  v_delta numeric;
  v_nueva_existencia numeric;
begin
  if p_cantidad_objetivo is null or p_cantidad_objetivo < 0 then
    raise exception 'La cantidad objetivo debe ser mayor o igual a cero';
  end if;

  select id into v_producto_id
  from productos
  where negocio_id = p_negocio_id
    and nombre_normalizado = lower(nullif(trim(p_nombre), ''))
  limit 1;

  if v_producto_id is null then
    return false;
  end if;

  select coalesce(existencia_actual, 0), coalesce(costo_promedio_actual, 0)
  into v_existencia_actual, v_costo_promedio
  from inventario
  where producto_id = v_producto_id;

  if not found then
    v_existencia_actual := 0;
    v_costo_promedio := 0;
  end if;

  v_delta := p_cantidad_objetivo - v_existencia_actual;
  v_nueva_existencia := p_cantidad_objetivo;

  -- Ajuste: no cambia el costo promedio, solo la existencia.
  if v_delta <> 0 then
    insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
    values (v_producto_id, v_nueva_existencia, v_costo_promedio)
    on conflict (producto_id)
    do update set existencia_actual = excluded.existencia_actual,
                  actualizado_en = now();

    insert into movimientos_inventario (
      producto_id, tipo_movimiento, cantidad, costo_unitario,
      existencia_resultante, costo_promedio_resultante, fecha
    ) values (
      v_producto_id, 'ajuste', v_delta, v_costo_promedio,
      v_nueva_existencia, v_costo_promedio, current_date
    );
  end if;

  return true;
end;
$$;

grant execute on function actualizar_producto(uuid, text, numeric, numeric, numeric)
  to anon, authenticated;
grant execute on function ajustar_inventario(uuid, text, numeric)
  to anon, authenticated;
