# Instrucciones de desarrollo — Prototipo de asistente financiero conversacional

**Para:** IA/agente de desarrollo encargado de construir el prototipo en Flutter.
**Objetivo de este documento:** especificar exactamente qué construir, en qué orden, con qué stack y con qué esquema de base de datos. No es la app final — es un prototipo funcional para validar el ciclo: voz → texto → clasificación con IA → confirmación → guardado en base de datos.

---

## 1. Contexto del proyecto

Se está construyendo un asistente financiero conversacional para microempresarios sin formación contable. El usuario habla o escribe una transacción en lenguaje cotidiano (ej. "vendí Q200 de fruta hoy"), el sistema la transcribe, la clasifica con un LLM, y la registra en una base de datos contable simplificada (contabilidad de caja, no partida doble).

Este prototipo **no** debe incluir: autenticación multiusuario completa, sincronización offline robusta, dashboard dinámico final, ni diseño visual pulido. El foco es que el ciclo funcional funcione de punta a punta y sea demostrable con emprendedores reales de prueba.

---

## 2. Stack técnico (fijo, no cambiar sin consultar)

| Componente | Tecnología |
|---|---|
| App móvil | Flutter |
| Manejo de estado | Riverpod |
| Backend / base de datos | Supabase (Postgres) |
| Voz a texto | Paquete `speech_to_text` (nativo del dispositivo) para este prototipo — no usar Whisper todavía, para evitar costo y complejidad de manejo de archivos de audio en esta fase |
| Clasificación / NLU | Llamada HTTP a la API de un LLM con salida forzada en JSON (Claude o GPT — usar la que ya tenga API key configurada) |
| HTTP client | `dio` o `http` |
| Variables de entorno | `flutter_dotenv` — nunca hardcodear API keys en el código |

### Paquetes Flutter a instalar
```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  supabase_flutter: ^2.5.6
  speech_to_text: ^7.0.0
  permission_handler: ^11.3.1
  dio: ^5.4.3
  flutter_dotenv: ^5.1.0
  uuid: ^4.4.0
  intl: ^0.19.0
```

---

## 3. Esquema de base de datos (Supabase / Postgres)

Ejecutar este script completo en el SQL Editor de Supabase antes de conectar la app.

```sql
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
```

### Nota sobre seguridad (RLS)
Para este prototipo interno pueden dejar las tablas sin Row Level Security mientras solo lo prueba el equipo. **Antes de dar el sistema a los emprendedores piloto**, es obligatorio activar RLS en Supabase y crear políticas que limiten cada `negocio_id` a ver únicamente sus propios datos. No dejar esto para el final — agregarlo como tarea explícita antes de cualquier prueba con usuarios reales.

---

## 4. Fases de construcción del prototipo

Construir en este orden. No avanzar a la siguiente fase sin cumplir el criterio de aceptación de la anterior.

### Fase 0 — Setup del proyecto
**Tareas:**
1. Crear proyecto Flutter nuevo.
2. Instalar los paquetes listados en la sección 2.
3. Crear proyecto en Supabase y ejecutar el script SQL completo de la sección 3.
4. Configurar `.env` con: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `LLM_API_KEY`.
5. Verificar conexión: la app debe poder leer la tabla `categorias` y mostrar las 8 categorías nivel 1 en consola o en una lista simple.

**Criterio de aceptación:** la app arranca, conecta a Supabase, y muestra las 8 categorías sembradas.

---

### Fase 1 — Captura de voz y visualización de la transcripción
**Tareas:**
1. Pantalla simple tipo chat con un botón de micrófono.
2. Al presionar, usar `speech_to_text` para capturar y transcribir el audio en español (`locale: 'es_GT'` si está disponible, si no `'es_ES'` o `'es_MX'` como fallback).
3. Mostrar el texto transcrito en un campo de texto **editable** (el usuario debe poder corregirlo antes de continuar).
4. Botón "Enviar" que solo se habilita cuando hay texto.

**Criterio de aceptación:** el usuario habla, ve el texto transcrito, puede editarlo, y puede confirmarlo para continuar. No debe haber llamada al LLM todavía en esta fase.

---

### Fase 2 — Envío al LLM y enrutamiento de intención

El texto confirmado en la Fase 1 se envía a la API del LLM. El LLM **siempre** debe responder en este formato JSON (usar salida estructurada/JSON forzado, no parseo de texto libre):

```json
{
  "tipo_respuesta": "transaccion",
  "mensaje_para_usuario": "Detecté una venta de Q200. ¿Confirmas?",
  "datos_transaccion": {
    "monto": 200,
    "tipo": "ingreso",
    "categoria_nivel1_sugerida": "Ingresos",
    "categoria_nivel2_sugerida": "Venta de producto",
    "confianza": 0.92
  }
}
```

`tipo_respuesta` puede ser: `"transaccion"`, `"conversacion"`, o `"consulta_reporte"`. Cuando es `"conversacion"` o `"consulta_reporte"`, el campo `datos_transaccion` debe venir como `null`.

**System prompt sugerido para el LLM** (ajustar según el proveedor elegido):
```
Eres un asistente que clasifica mensajes de microempresarios guatemaltecos sobre
su negocio. Debes responder EXCLUSIVAMENTE en JSON válido, sin texto adicional,
siguiendo este esquema exacto: {tipo_respuesta, mensaje_para_usuario, datos_transaccion}.

Las categorías de nivel 1 disponibles son: Ingresos, Costos de venta, Gastos
operativos, Gastos administrativos, Otros gastos, Inversiones, Préstamos y
financiamiento, Retiros personales.

Si el mensaje describe una transacción de dinero (venta, compra, pago, gasto,
préstamo, retiro), usa tipo_respuesta = "transaccion" y llena datos_transaccion.
Si el mensaje es un saludo, pregunta general o algo ambiguo sin datos financieros
claros, usa tipo_respuesta = "conversacion" y datos_transaccion = null.
Si el usuario pide ver un reporte o resumen, usa tipo_respuesta = "consulta_reporte"
y datos_transaccion = null.
```

**Tareas de la app:**
1. Enviar el texto confirmado al LLM junto con el system prompt.
2. Parsear la respuesta JSON.
3. Según `tipo_respuesta`:
   - `"transaccion"` → mostrar una tarjeta de confirmación con monto, tipo y categoría sugerida, con botones "Confirmar" y "Corregir".
   - `"conversacion"` → mostrar `mensaje_para_usuario` como burbuja de chat normal.
   - `"consulta_reporte"` → mostrar `mensaje_para_usuario` (puede ser un mensaje de "función aún no disponible en este prototipo").

**Criterio de aceptación:** probar con al menos 15 mensajes reales y variados (formales, coloquiales, saludos, preguntas ambiguas) y registrar manualmente cuántas veces el `tipo_respuesta` fue el correcto.

---

### Fase 3 — Confirmación y persistencia en Supabase
**Tareas:**
1. Al presionar "Confirmar" en la tarjeta de transacción, buscar o crear la categoría de nivel 2 sugerida dentro de `categorias` (ligada al negocio de prueba y al padre de nivel 1 correspondiente).
2. Insertar el registro en `transacciones` con `confirmado_por_usuario = true` y `origen` correcto (`voz` o `texto`).
3. Insertar siempre un registro en `conversaciones`, haya derivado o no en una transacción, con el `intencion_detectada` correspondiente.
4. Si el usuario presiona "Corregir" en vez de "Confirmar", permitir que edite monto/categoría antes de guardar.

**Criterio de aceptación:** el ciclo completo funciona de punta a punta — hablar, ver texto, ver clasificación, confirmar, y verificar en el panel de Supabase que la fila apareció correctamente en `transacciones` y en `conversaciones`.

---

### Fase 4 (opcional, si el tiempo lo permite) — Totales básicos
**Tareas:**
1. Pantalla simple que consulte `vista_ingresos` y `vista_egresos` y muestre el total del mes actual de cada una.
2. No es el dashboard dinámico final — solo dos números en pantalla para demostrar que las vistas funcionan.

**Criterio de aceptación:** los totales mostrados coinciden con la suma manual de las transacciones insertadas durante las pruebas.

---

## 5. Explícitamente fuera de alcance de este prototipo
No construir lo siguiente todavía, aunque esté en la propuesta general del proyecto:
- Autenticación completa multiusuario (usar un negocio y usuario fijo de prueba, sembrado manualmente en la base de datos)
- Manejo offline / sincronización robusta
- Dashboard dinámico con selección automática de widgets
- Integración con WhatsApp
- Row Level Security (agregar solo antes de pruebas con emprendedores reales, ver sección 3)
- Diseño visual final — usar componentes básicos de Flutter, sin invertir tiempo en estética todavía