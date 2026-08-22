-- ==========================================
-- FASE 6b: desglose cantidad × precio unitario
-- ==========================================

alter table transacciones
  add column if not exists cantidad numeric,
  add column if not exists precio_unitario numeric;

-- Listado con desglose y descripción normalizada (formateada por la IA)
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
  precio_unitario numeric
)
language sql
stable
as $$
  select t.fecha, t.tipo::text, t.monto,
         c1.nombre, c2.nombre,
         coalesce(t.descripcion_normalizada, t.descripcion_original),
         t.origen::text,
         t.cantidad, t.precio_unitario
  from transacciones t
  left join categorias c2 on c2.id = t.categoria_id
  left join categorias c1 on c1.id = c2.categoria_padre_id
  where t.negocio_id = p_negocio_id
    and t.confirmado_por_usuario = true
    and (p_tipo is null or t.tipo = p_tipo::tipo_movimiento)
  order by t.fecha desc, t.creado_en desc
  limit p_limite;
$$;

grant execute on function obtener_listado_transacciones(uuid, text, integer) to anon, authenticated;
