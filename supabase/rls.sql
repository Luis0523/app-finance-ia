-- ==========================================
-- ROW LEVEL SECURITY
-- Cada negocio solo ve sus propios datos.
-- La app identifica el negocio con el header
-- 'x-negocio-id' (uuid del negocio de sesión).
-- ==========================================

-- Helper: uuid del negocio de sesión (o null si no hay header)
create or replace function session_negocio_id()
returns uuid
language sql
stable
as $$
  select (current_setting('request.headers', true)::jsonb ->> 'x-negocio-id')::uuid
$$;

-- ==========================================
-- NEGOCIOS (registro de acceso público de solo lectura)
-- ==========================================
alter table negocios enable row level security;
create policy "negocios lectura anon"
  on negocios for select to anon, authenticated
  using (true);

-- ==========================================
-- USUARIOS
-- ==========================================
alter table usuarios enable row level security;
create policy "usuarios de su negocio"
  on usuarios for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

-- ==========================================
-- CUENTAS DE DINERO
-- ==========================================
alter table cuentas_dinero enable row level security;
create policy "cuentas de su negocio"
  on cuentas_dinero for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

-- ==========================================
-- CATEGORIAS (globales visibles + propias del negocio)
-- ==========================================
alter table categorias enable row level security;
create policy "categorias globales y de su negocio"
  on categorias for all to anon, authenticated
  using (negocio_id is null or negocio_id = session_negocio_id())
  with check (negocio_id is null or negocio_id = session_negocio_id());

-- ==========================================
-- PRESTAMOS
-- ==========================================
alter table prestamos enable row level security;
create policy "prestamos de su negocio"
  on prestamos for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

-- ==========================================
-- INVERSIONES
-- ==========================================
alter table inversiones enable row level security;
create policy "inversiones de su negocio"
  on inversiones for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

-- ==========================================
-- TRANSACCIONES
-- ==========================================
alter table transacciones enable row level security;
create policy "transacciones de su negocio"
  on transacciones for all to anon, authenticated
  using (negocio_id = session_negocio_id())
  with check (negocio_id = session_negocio_id());

-- ==========================================
-- CONVERSACIONES (vía el negocio del usuario)
-- ==========================================
alter table conversaciones enable row level security;
create policy "conversaciones de su negocio"
  on conversaciones for all to anon, authenticated
  using (
    exists (
      select 1 from usuarios u
      where u.id = conversaciones.usuario_id
        and u.negocio_id = session_negocio_id()
    )
  )
  with check (
    exists (
      select 1 from usuarios u
      where u.id = conversaciones.usuario_id
        and u.negocio_id = session_negocio_id()
    )
  );
