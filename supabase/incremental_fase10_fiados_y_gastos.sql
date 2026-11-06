-- ============================================================================
-- FASE 10 INCREMENTAL: CUADERNO DE FIADOS (CUENTAS POR COBRAR) Y ABONOS
-- NO borra datos existentes. Es 100% incremental y compatible.
-- ============================================================================

-- 1. TABLA CUENTAS POR COBRAR (FIADOS)
create table if not exists cuentas_por_cobrar (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  cliente_nombre text not null,
  cliente_telefono text,
  monto_total numeric(12,2) not null check (monto_total > 0),
  saldo_pendiente numeric(12,2) not null check (saldo_pendiente >= 0),
  descripcion text,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'parcial', 'pagado')),
  fecha date not null default current_date,
  fecha_limite date,
  transaccion_id uuid references transacciones(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists idx_cuentas_cobrar_negocio on cuentas_por_cobrar(negocio_id);
create index if not exists idx_cuentas_cobrar_estado on cuentas_por_cobrar(negocio_id, estado);
create index if not exists idx_cuentas_cobrar_cliente on cuentas_por_cobrar(negocio_id, cliente_nombre);

-- 2. TABLA ABONOS DE CUENTAS POR COBRAR
create table if not exists abonos_cuentas_cobrar (
  id uuid primary key default gen_random_uuid(),
  cuenta_cobrar_id uuid not null references cuentas_por_cobrar(id) on delete cascade,
  monto numeric(12,2) not null check (monto > 0),
  metodo_pago text not null default 'efectivo',
  fecha date not null default current_date,
  notas text,
  creado_en timestamptz not null default now()
);

create index if not exists idx_abonos_cuenta on abonos_cuentas_cobrar(cuenta_cobrar_id);

-- 3. TRIGGER PARA ACTUALIZAR SALDO Y ESTADO DE LA CUENTA POR COBRAR
create or replace function fn_actualizar_saldo_cuenta_cobrar()
returns trigger as $$
declare
  v_cuenta_id uuid;
  v_monto_total numeric(12,2);
  v_total_abonado numeric(12,2);
  v_nuevo_saldo numeric(12,2);
  v_nuevo_estado text;
begin
  if (TG_OP = 'DELETE') then
    v_cuenta_id := old.cuenta_cobrar_id;
  else
    v_cuenta_id := new.cuenta_cobrar_id;
  end if;

  select monto_total into v_monto_total
  from cuentas_por_cobrar
  where id = v_cuenta_id;

  select coalesce(sum(monto), 0) into v_total_abonado
  from abonos_cuentas_cobrar
  where cuenta_cobrar_id = v_cuenta_id;

  v_nuevo_saldo := greatest(0, round(v_monto_total - v_total_abonado, 2));

  if v_nuevo_saldo <= 0 then
    v_nuevo_estado := 'pagado';
  elsif v_total_abonado > 0 then
    v_nuevo_estado := 'parcial';
  else
    v_nuevo_estado := 'pendiente';
  end if;

  update cuentas_por_cobrar
  set saldo_pendiente = v_nuevo_saldo,
      estado = v_nuevo_estado,
      actualizado_en = now()
  where id = v_cuenta_id;

  return null;
end;
$$ language plpgsql;

drop trigger if exists trg_actualizar_saldo_cuenta_cobrar on abonos_cuentas_cobrar;
create trigger trg_actualizar_saldo_cuenta_cobrar
after insert or update or delete on abonos_cuentas_cobrar
for each row execute function fn_actualizar_saldo_cuenta_cobrar();

-- 4. RLS POLICIES
alter table cuentas_por_cobrar enable row level security;
drop policy if exists "cuentas_por_cobrar de su negocio" on cuentas_por_cobrar;
create policy "cuentas_por_cobrar de su negocio"
  on cuentas_por_cobrar for all to anon, authenticated
  using (negocio_id = session_negocio_id() or session_negocio_id() is null)
  with check (negocio_id = session_negocio_id() or session_negocio_id() is null);

alter table abonos_cuentas_cobrar enable row level security;
drop policy if exists "abonos de cuentas de su negocio" on abonos_cuentas_cobrar;
create policy "abonos de cuentas de su negocio"
  on abonos_cuentas_cobrar for all to anon, authenticated
  using (
    exists (
      select 1 from cuentas_por_cobrar c
      where c.id = abonos_cuentas_cobrar.cuenta_cobrar_id
        and (c.negocio_id = session_negocio_id() or session_negocio_id() is null)
    )
  )
  with check (
    exists (
      select 1 from cuentas_por_cobrar c
      where c.id = abonos_cuentas_cobrar.cuenta_cobrar_id
        and (c.negocio_id = session_negocio_id() or session_negocio_id() is null)
    )
  );

-- 5. PERMISOS
grant usage on schema public to anon, authenticated;
grant all on table cuentas_por_cobrar to anon, authenticated;
grant all on table abonos_cuentas_cobrar to anon, authenticated;
