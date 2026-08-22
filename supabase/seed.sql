-- ==========================================
-- SEED: datos de prueba para el prototipo
-- Negocio, usuario y cuenta de dinero fijos.
-- Ejecutar después de supabase/schema.sql.
-- ==========================================

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
