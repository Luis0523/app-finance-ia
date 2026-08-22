-- ==========================================
-- RPC: análisis y consultas específicas
-- Devuelven agregados SQL; el LLM solo recibe
-- estos resúmenes, nunca las transacciones.
-- ==========================================

-- Última transacción confirmada (opcional: filtrar por tipo ingreso/egreso)
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

-- Resumen del mes: totales + desglose por categoría (nivel 1 y 2)
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

grant execute on function obtener_ultima_transaccion(uuid, text) to anon, authenticated;
grant execute on function obtener_resumen_analisis(uuid) to anon, authenticated;
