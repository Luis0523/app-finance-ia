-- ==========================================
-- ENUMS
-- ==========================================
create type tipo_movimiento as enum ('ingreso', 'egreso');
create type origen_transaccion as enum ('voz', 'texto', 'manual');
create type tipo_cuenta_dinero as enum ('efectivo', 'banco', 'digital');
create type tipo_intencion as enum ('conversacional', 'transaccional', 'consulta_reporte');

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
-- CATEGORIAS
-- Decisión de diseño: se deja el campo "tipo" en cada fila (denormalización
-- controlada) por rendimiento, pero se fuerza con un trigger que el tipo
-- de una subcategoría siempre coincida con el de su categoría padre.
-- ==========================================
create table categorias (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references negocios(id) on delete cascade, -- null = categoría global del sistema
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

-- Seed: las 8 categorías de nivel 1 (globales, negocio_id = null)
insert into categorias (nombre, tipo, categoria_padre_id, negocio_id) values
  ('Ingresos', 'ingreso', null, null),
  ('Costos de venta', 'egreso', null, null),
  ('Gastos operativos', 'egreso', null, null),
  ('Gastos administrativos', 'egreso', null, null),
  ('Otros gastos', 'egreso', null, null),
  ('Inversiones', 'egreso', null, null),
  ('Préstamos y financiamiento', 'egreso', null, null),
  ('Retiros personales', 'egreso', null, null);

-- ==========================================
-- PRESTAMOS
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

-- ==========================================
-- INVERSIONES
-- ==========================================
create table inversiones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  descripcion text not null,
  valor_adquisicion numeric(12,2) not null,
  vida_util_meses int,
  fecha_adquisicion date not null default current_date
);

-- ==========================================
-- TRANSACCIONES (tabla central)
-- ==========================================
create table transacciones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  cuenta_dinero_id uuid references cuentas_dinero(id),
  categoria_id uuid not null references categorias(id),
  monto numeric(12,2) not null check (monto > 0),
  tipo tipo_movimiento not null,
  descripcion_original text,
  descripcion_normalizada text,
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
-- VISTAS: ingresos y egresos por separado, sin duplicar datos
-- ==========================================
create view vista_ingresos as
  select * from transacciones where tipo = 'ingreso';

create view vista_egresos as
  select * from transacciones where tipo = 'egreso';
