# Lógica de negocio: inventario, compras y ventas

**Para:** IA/agente de desarrollo del prototipo.
**Objetivo:** dejar clara la relación entre inventario, compras y ventas antes de seguir programando, porque hasta ahora se estaban mezclando conceptos que en contabilidad son distintos. Este documento define la lógica correcta y las tablas que la sostienen.

---

## 1. El problema de fondo (por qué se estaba confundiendo)

Hasta ahora existía una sola idea de "costo" (`producto_costos`), pero en realidad hay **tres momentos distintos** en la vida de un producto, y cada uno mueve el inventario de forma diferente:

1. **Comprar** algo ya hecho a un proveedor para revenderlo (ej. una tienda que compra gaseosas).
2. **Fabricar/producir** algo usando una receta de insumos (ej. un comedor que hace tamales con harina, carne, hoja).
3. **Vender** lo que ya está en existencia, sea comprado o fabricado.

`producto_costos` (la receta de insumos) **solo aplica al caso 2**. No es lo mismo que "cuánto me costó lo que tengo en bodega" — eso lo determina el inventario, no la receta. Mezclar ambos conceptos es lo que estaba generando la confusión.

La solución es tener **un solo registro histórico de movimientos de inventario (kardex)** que sea la única fuente de verdad de cuánta existencia hay y a qué costo, alimentado por compras y producciones, y consultado (nunca recalculado a mano) cuando se vende.

---

## 2. Método de costeo a usar: costo promedio ponderado (CPP)

Cuando llegan unidades nuevas a distinto costo que las que ya había (ej. compré 10 unidades a Q5, luego compré 10 más a Q6), el sistema **no debe preguntar cuál lote se vendió** (eso sería FIFO, más complejo). Se usa **costo promedio ponderado**, que es el estándar recomendado para microempresas por su simplicidad:

```
nuevo_costo_promedio = (existencia_actual * costo_promedio_actual + cantidad_nueva * costo_unitario_nuevo)
                        ÷ (existencia_actual + cantidad_nueva)
```

Cada vez que entra inventario (por compra o por producción), se recalcula este promedio. Cada vez que sale (por venta), se usa el promedio vigente **en ese momento** — y ese valor se congela en la transacción de venta, para que si el costo cambia después, los reportes de ventas pasadas no se alteren retroactivamente.

---

## 3. Columnas imprescindibles (mínimo indispensable para que la contabilidad sea correcta)

| Tabla | Columnas clave | Por qué son imprescindibles |
|---|---|---|
| `productos` | `precio_venta`, `unidad_medida`, `tipo_producto` (reventa / fabricado) | Sin `tipo_producto` el sistema no sabe si debe esperar una compra o una receta de producción |
| `inventario` | `existencia_actual`, `costo_promedio_actual` | Es la única fuente de verdad de "cuánto tengo" y "a qué costo" — sin esto, cualquier cálculo de ganancia es una suposición |
| `movimientos_inventario` (kardex) | `tipo_movimiento`, `cantidad`, `costo_unitario`, `existencia_resultante`, `costo_promedio_resultante` | Sin este historial no hay forma de auditar por qué el inventario quedó en cierto número, ni de detectar un error de captura |
| `compras` | `cantidad`, `costo_unitario`, `proveedor` | El costo real de reventa viene de aquí, no de una receta |
| `producto_costos` | `descripcion`, `costo` | Es la receta — solo se usa para calcular el costo de un lote producido, no el costo de cada venta individual |
| `transacciones` (venta) | `costo_unitario_momento_venta`, `utilidad_calculada` | Sin congelar el costo al momento de la venta, la "ganancia real" cambiaría cada vez que cambien los costos futuros, lo cual sería incorrecto contablemente |

---

## 4. Esquema SQL (ejecutar sobre lo que ya existe en Supabase)

```sql
-- Ajuste a productos: distinguir cómo se repone su existencia
alter table productos
  add column unidad_medida text not null default 'unidad',
  add column tipo_producto text not null default 'reventa'
    check (tipo_producto in ('reventa', 'fabricado'));

-- ==========================================
-- INVENTARIO: foto actual de existencia y costo por producto
-- ==========================================
create table inventario (
  producto_id uuid primary key references productos(id) on delete cascade,
  existencia_actual numeric(12,2) not null default 0,
  costo_promedio_actual numeric(12,2) not null default 0,
  valor_inventario numeric(12,2) generated always as (existencia_actual * costo_promedio_actual) stored,
  actualizado_en timestamptz not null default now()
);

-- ==========================================
-- KARDEX: historial de cada entrada o salida (fuente de verdad auditable)
-- ==========================================
create type tipo_movimiento_inventario as enum ('compra', 'produccion', 'venta', 'ajuste');

create table movimientos_inventario (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references productos(id),
  tipo_movimiento tipo_movimiento_inventario not null,
  cantidad numeric(12,2) not null, -- positivo = entrada, negativo = salida
  costo_unitario numeric(12,2) not null,
  existencia_resultante numeric(12,2) not null,
  costo_promedio_resultante numeric(12,2) not null,
  referencia_compra_id uuid,
  referencia_transaccion_id uuid references transacciones(id),
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

-- ==========================================
-- COMPRAS: entrada de inventario comprado a proveedor
-- ==========================================
create table compras (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  producto_id uuid not null references productos(id),
  proveedor text,
  cantidad numeric(12,2) not null check (cantidad > 0),
  costo_unitario numeric(12,2) not null check (costo_unitario >= 0),
  costo_total numeric(12,2) generated always as (cantidad * costo_unitario) stored,
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

-- ==========================================
-- PRODUCCIONES: entrada de inventario fabricado con receta (producto_costos)
-- ==========================================
create table producciones (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references productos(id),
  cantidad_producida numeric(12,2) not null check (cantidad_producida > 0),
  costo_total_lote numeric(12,2) not null, -- normalmente = suma de producto_costos vigente
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);

-- Congelar el costo y la utilidad real en cada venta
alter table transacciones
  add column costo_unitario_momento_venta numeric(12,2),
  add column utilidad_calculada numeric(12,2);
```

### Trigger: registrar una compra (entrada de inventario comprado)

```sql
create or replace function fn_registrar_compra()
returns trigger as $$
declare
  inv record;
  nueva_existencia numeric;
  nuevo_costo_prom numeric;
begin
  select * into inv from inventario where producto_id = new.producto_id for update;
  if not found then
    insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
      values (new.producto_id, 0, 0);
    select * into inv from inventario where producto_id = new.producto_id for update;
  end if;

  nueva_existencia := inv.existencia_actual + new.cantidad;
  nuevo_costo_prom := (inv.existencia_actual * inv.costo_promedio_actual + new.cantidad * new.costo_unitario) / nueva_existencia;

  update inventario
    set existencia_actual = nueva_existencia,
        costo_promedio_actual = nuevo_costo_prom,
        actualizado_en = now()
    where producto_id = new.producto_id;

  insert into movimientos_inventario
    (producto_id, tipo_movimiento, cantidad, costo_unitario, existencia_resultante, costo_promedio_resultante, referencia_compra_id, fecha)
  values
    (new.producto_id, 'compra', new.cantidad, new.costo_unitario, nueva_existencia, nuevo_costo_prom, new.id, new.fecha);

  return new;
end;
$$ language plpgsql;

create trigger trg_registrar_compra
after insert on compras
for each row execute function fn_registrar_compra();
```

### Trigger: registrar una producción (entrada de inventario fabricado)

Misma lógica que una compra, pero el costo unitario sale de dividir `costo_total_lote / cantidad_producida` en vez de venir de un proveedor. Se recomienda replicar la misma estructura del trigger anterior, cambiando `tipo_movimiento` a `'produccion'` y usando `referencia_compra_id` como `null` (agregar un `referencia_produccion_id` si se quiere trazabilidad completa).

### Trigger: registrar una venta (salida de inventario + utilidad real)

```sql
create or replace function fn_registrar_venta_inventario()
returns trigger as $$
declare
  inv record;
  nueva_existencia numeric;
begin
  if new.producto_id is not null and new.tipo = 'ingreso' then
    select * into inv from inventario where producto_id = new.producto_id for update;

    if found then
      nueva_existencia := inv.existencia_actual - new.cantidad;

      update transacciones
        set costo_unitario_momento_venta = inv.costo_promedio_actual,
            utilidad_calculada = (new.monto / nullif(new.cantidad, 0) - inv.costo_promedio_actual) * new.cantidad
        where id = new.id;

      update inventario
        set existencia_actual = nueva_existencia,
            actualizado_en = now()
        where producto_id = new.producto_id;

      insert into movimientos_inventario
        (producto_id, tipo_movimiento, cantidad, costo_unitario, existencia_resultante, costo_promedio_resultante, referencia_transaccion_id, fecha)
      values
        (new.producto_id, 'venta', -new.cantidad, inv.costo_promedio_actual, nueva_existencia, inv.costo_promedio_actual, new.id, new.fecha);
    end if;
  end if;

  return new;
end;
$$ language plpgsql;

create trigger trg_registrar_venta_inventario
after insert on transacciones
for each row execute function fn_registrar_venta_inventario();
```

> Nota importante: con este trigger, `producto_costos` **deja de usarse para calcular la utilidad de cada venta** — solo se usa para calcular `costo_total_lote` cuando se registra una `produccion`. La utilidad real siempre sale de `inventario.costo_promedio_actual`, que es el número que de verdad refleja lo que cuesta reponer ese producto hoy.

---

## 5. Flujo para registrar un producto nuevo (lo que pidieron para más adelante)

Cuando el usuario dice algo como *"voy a crear un producto nuevo para vender, los costos son: harina Q15, empaque Q3, mano de obra Q10"*, el flujo correcto es:

1. **Crear el producto** en `productos` con `tipo_producto = 'fabricado'` (porque tiene receta) y el `precio_venta` que el usuario indique.
2. **Registrar cada costo mencionado como una fila separada en `producto_costos`** (no como un solo número sumado) — así después se puede editar o quitar un insumo sin perder el detalle.
3. Si el usuario ya tiene unidades hechas para vender, **registrar una `produccion`**: cantidad producida y `costo_total_lote` (que puede calcularse sumando `producto_costos` automáticamente, o dejar que el usuario ajuste el total si compró en volumen). Esto es lo que realmente crea existencia en `inventario` vía el trigger.
4. Si en cambio el producto es de reventa (`tipo_producto = 'reventa'`), no se usa `producto_costos` — se espera una fila en `compras` en su lugar.
5. A partir de ahí, cada venta de ese producto (una `transaccion` tipo ingreso con `producto_id` y `cantidad`) descuenta automáticamente el inventario y calcula la utilidad real usando el costo promedio vigente — el usuario nunca tiene que calcular la ganancia a mano, ni el asistente conversacional tiene que volver a preguntar "¿cuánto te costó esto?" en cada venta.

Este es exactamente el punto que evita la confusión original: **la receta de costos se declara una sola vez al crear/producir el producto, no en cada venta.**