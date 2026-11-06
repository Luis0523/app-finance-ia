-- ==========================================
-- AUTENTICACIÓN CON SUPABASE AUTH
-- Ejecutar UNA VEZ en el SQL Editor de Supabase
-- sobre la base existente.
--
-- Qué hace:
--   1. Vincula la tabla public.usuarios con auth.users.
--   2. Al registrarse, crea automáticamente el negocio y el perfil.
--   3. El primer usuario registrado adopta el negocio ya existente
--      (para no perder los datos actuales). Los siguientes usuarios
--      crean su propio negocio.
--   4. RLS deja de confiar en el header x-negocio-id y pasa a usar
--      la sesión real (auth.uid()).
-- ==========================================

-- ==========================================
-- 1. COLUMNAS DE AUTH EN USUARIOS
-- ==========================================
alter table public.usuarios
  add column if not exists auth_user_id uuid references auth.users(id) on delete cascade;
alter table public.usuarios add column if not exists email text;
alter table public.usuarios add column if not exists nombre text;

create unique index if not exists usuarios_auth_user_id_key
  on public.usuarios (auth_user_id)
  where auth_user_id is not null;

-- ==========================================
-- 2. ALTA AUTOMÁTICA DE NEGOCIO + USUARIO
-- ==========================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_negocio_id uuid;
  v_usuario_id uuid;
  v_nombre_negocio text;
  v_nombre text;
begin
  v_nombre_negocio := nullif(trim(new.raw_user_meta_data ->> 'nombre_negocio'), '');
  v_nombre := nullif(trim(new.raw_user_meta_data ->> 'nombre'), '');

  -- El primer usuario registrado adopta el negocio existente para
  -- conservar los datos que ya había en la base.
  if not exists (select 1 from public.usuarios where auth_user_id is not null) then
    select u.id, u.negocio_id
      into v_usuario_id, v_negocio_id
    from public.usuarios u
    join public.negocios n on n.id = u.negocio_id
    order by n.creado_en, u.creado_en
    limit 1;

    if v_usuario_id is not null then
      update public.usuarios
      set auth_user_id = new.id,
          email = new.email,
          nombre = coalesce(v_nombre, nombre)
      where id = v_usuario_id;

      return new;
    end if;
  end if;

  if v_nombre_negocio is null then
    v_nombre_negocio := 'Mi negocio';
  end if;

  insert into public.negocios (nombre)
  values (v_nombre_negocio)
  returning id into v_negocio_id;

  insert into public.usuarios (negocio_id, auth_user_id, email, nombre, rol)
  values (v_negocio_id, new.id, new.email, v_nombre, 'dueño');

  insert into public.cuentas_dinero (negocio_id, nombre, tipo, saldo_actual)
  values (v_negocio_id, 'Efectivo', 'efectivo', 0);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ==========================================
-- 3. LIMPIEZA AL ELIMINAR UN USUARIO
-- ==========================================
create or replace function public.handle_user_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_negocio_id uuid;
begin
  select negocio_id into v_negocio_id
  from public.usuarios
  where auth_user_id = old.id
  limit 1;

  delete from public.usuarios where auth_user_id = old.id;

  if v_negocio_id is not null
     and not exists (
       select 1 from public.usuarios where negocio_id = v_negocio_id
     ) then
    delete from public.negocios where id = v_negocio_id;
  end if;

  return old;
end;
$$;

drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  before delete on auth.users
  for each row execute function public.handle_user_delete();

-- ==========================================
-- 4. NEGOCIO DE LA SESIÓN (reemplaza x-negocio-id)
-- ==========================================
create or replace function public.session_negocio_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select negocio_id
  from public.usuarios
  where auth_user_id = auth.uid()
  limit 1
$$;

grant execute on function public.session_negocio_id() to authenticated;

-- ==========================================
-- 5. POLÍTICAS RLS
-- ==========================================
-- Solo se puede ver el negocio al que pertenece el usuario.
drop policy if exists "negocios lectura anon" on public.negocios;
drop policy if exists "negocios de su usuario" on public.negocios;
create policy "negocios de su usuario"
  on public.negocios for select to authenticated
  using (id = public.session_negocio_id());

-- Perfiles: solo los del propio negocio y solo con sesión.
drop policy if exists "usuarios de su negocio" on public.usuarios;
create policy "usuarios de su negocio"
  on public.usuarios for all to authenticated
  using (negocio_id = public.session_negocio_id())
  with check (negocio_id = public.session_negocio_id());

-- Categorías: las globales (negocio_id null) son de solo lectura;
-- las propias se pueden crear/editar/borrar.
drop policy if exists "categorias globales y de su negocio" on public.categorias;
drop policy if exists "categorias lectura" on public.categorias;
drop policy if exists "categorias escritura" on public.categorias;
drop policy if exists "categorias actualizar" on public.categorias;
drop policy if exists "categorias borrar" on public.categorias;

create policy "categorias lectura"
  on public.categorias for select to authenticated
  using (negocio_id is null or negocio_id = public.session_negocio_id());

create policy "categorias escritura"
  on public.categorias for insert to authenticated
  with check (negocio_id = public.session_negocio_id());

create policy "categorias actualizar"
  on public.categorias for update to authenticated
  using (negocio_id = public.session_negocio_id())
  with check (negocio_id = public.session_negocio_id());

create policy "categorias borrar"
  on public.categorias for delete to authenticated
  using (negocio_id = public.session_negocio_id());

-- ==========================================
-- 6. PERMISOS
-- ==========================================
grant usage on schema public to authenticated;
grant all on all tables in schema public to authenticated;
grant all on all sequences in schema public to authenticated;
