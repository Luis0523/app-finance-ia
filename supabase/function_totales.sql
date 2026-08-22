-- ==========================================
-- RPC: totales del mes actual por negocio
-- Usa agregados SQL exactos sobre la tabla
-- central; el LLM nunca ve los datos crudos.
-- ==========================================

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

grant execute on function obtener_totales_mes(uuid) to anon, authenticated;
