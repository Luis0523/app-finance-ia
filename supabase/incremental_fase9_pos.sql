-- ============================================================================
-- FASE 9 INCREMENTAL: MÓDULO POS (PUNTO DE VENTA)
-- NO borra datos existentes. 100% incremental y compatible.
-- ============================================================================

-- 1. Agregar columna metodo_pago a transacciones si no existe
alter table transacciones
  add column if not exists metodo_pago text default 'efectivo';

-- 2. Asegurar categoría para ventas POS bajo Ingresos si no existiera
do $$
declare
  v_cat_padre_id uuid;
begin
  select id into v_cat_padre_id
  from categorias
  where tipo = 'ingreso' and categoria_padre_id is null
  limit 1;

  if v_cat_padre_id is not null then
    if not exists (
      select 1 from categorias
      where nombre = 'Ventas POS' and tipo = 'ingreso'
    ) then
      insert into categorias (nombre, tipo, categoria_padre_id, es_sistema)
      values ('Ventas POS', 'ingreso', v_cat_padre_id, true);
    end if;
  end if;
end $$;
