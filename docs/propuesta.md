# Propuesta técnica — Catálogo de cuentas y plan de prototipado
### Proyecto: Asistente financiero conversacional para microempresas (Quetzaltenango)

---

## Parte 0: Decisiones a cerrar ahora (antes de seguir avanzando)

Esto es lo que conviene dejar fijo por escrito ya, para no rediseñar a mitad de camino:

| Decisión | Definición propuesta |
|---|---|
| Stack móvil | **Flutter** |
| Backend/BD | **Supabase (Postgres)** |
| Modelo contable | Caja simplificada (no partida doble) |
| Moneda/precisión | Quetzales, `numeric(12,2)` |
| Estructura de transacciones | Tabla única con discriminador (ver justificación abajo, no tablas separadas por tipo) |
| Estado offline | La app debe poder guardar localmente y sincronizar después (ver nota técnica abajo) |
| Autenticación | Vía Supabase Auth, vinculada a número de teléfono si el canal principal es WhatsApp |
| LLM para clasificación | Uno con salida estructurada/JSON garantizada (Claude o GPT vía API) |
| STT | Definir si es Whisper (mejor precisión, cuesta por uso) o STT nativo del dispositivo (gratis, funciona offline, algo menos preciso en español coloquial) — recomendable probar ambos en la Fase 1 con frases reales antes de decidir |

**Sobre Flutter + Supabase:** es una combinación sólida y práctica para esto. Punto importante a definir dentro del stack: cómo van a manejar el modo offline en Flutter, porque Supabase por sí solo no da persistencia local automática. Dos caminos:
- Usar **Drift** (SQLite local en Flutter) como base de datos local, y sincronizar manualmente contra Supabase cuando hay conexión (más código, pero control total).
- Usar **Supabase con `PowerSync`** o un patrón de cola de sincronización simple (guardar transacciones pendientes en una tabla local y reintentarlas) — menos trabajo si el volumen de datos es bajo, que es el caso real de un microempresario.

Para el alcance de tesis, recomendaría empezar con la segunda opción (cola simple de sincronización) y solo pasar a Drift si el profesor/jurado pide robustez offline más seria.

También conviene definir ya: manejo de estado en Flutter (Riverpod o Bloc — cualquiera funciona, Riverpod suele ser más rápido de aprender) y qué modelo específico de LLM usarán (esto afecta cómo se diseña el prompt de salida estructurada).

---

## Parte 1: Propuesta de catálogo de cuentas

Este catálogo está pensado para **contabilidad simplificada de caja** (cash basis), que es lo realista para un microempresario sin formación contable — no partida doble completa. Se puede migrar a partida doble más adelante si el alcance de la tesis lo permite, pero para el prototipo inicial esto reduce la complejidad de clasificación de la IA sin perder utilidad para el usuario.

### Categorías principales (nivel 1 — fijas en el sistema)

| Código | Categoría | Naturaleza | Descripción |
|---|---|---|---|
| 1 | Ingresos | Entrada | Ventas de productos/servicios, ingresos varios |
| 2 | Costos de venta | Salida | Costo directo de lo vendido (materia prima, mercadería) |
| 3 | Gastos operativos | Salida | Renta del local, servicios, insumos de operación diaria |
| 4 | Gastos administrativos | Salida | Papelería, contabilidad, trámites, salarios administrativos |
| 5 | Otros gastos | Salida | Gastos no recurrentes o no clasificables en las anteriores |
| 6 | Inversiones | Salida | Compra de activos (equipo, mobiliario, mejoras) |
| 7 | Préstamos y financiamiento | Entrada/Salida | Préstamos recibidos, pagos de cuotas, intereses |
| 8 | Retiros personales | Salida | Dinero que el dueño saca del negocio para uso personal (clave para separar patrimonios) |

### Subcategorías (nivel 2 — editable/extensible por negocio)

Estas **no van fijas en el código**, van como registros en una tabla `categorias`, para que cada microempresa pueda tener las suyas sin tocar el esquema:

- **Ingresos:** venta de producto, venta de servicio, ingreso por comisión, otros ingresos
- **Costos de venta:** compra de mercadería, materia prima, empaque
- **Gastos operativos:** renta, luz, agua, internet, transporte, insumos
- **Gastos administrativos:** papelería, contabilidad/asesoría, trámites legales
- **Inversiones:** equipo, mobiliario, remodelación
- **Préstamos:** desembolso recibido, pago de cuota, interés pagado

> Investigar a fondo (según lo conversado antes): NIIF para PYMES, plan de cuentas para MIPYMES en Guatemala, y régimen de Pequeño Contribuyente ante la SAT — esto puede ajustar nombres/agrupaciones exactas antes de cerrar el catálogo definitivo.

---

## Parte 2: Esquema de base de datos propuesto (ampliado)

### Nota de diseño: ¿una tabla de transacciones, o tablas separadas de ingresos/egresos?

Antes de ver las tablas, vale la pena resolver esto porque cambia todo el esquema:

**No recomiendo separar `ingresos` y `egresos` en dos tablas físicas distintas.** Razón: en cualquier reporte real (flujo de caja, estado de resultados, dashboard) van a necesitar sumar y restar ambos tipos juntos ordenados por fecha — con tablas separadas eso obliga a hacer `UNION` en cada consulta, duplicar columnas (fecha, monto, descripción existen en ambas), y si mañana agregan un campo (ej. "adjuntar foto del recibo") hay que agregarlo dos veces y mantenerlo sincronizado en dos lugares. Es la razón por la que casi todo software contable real usa una tabla única de movimientos con un campo `tipo`.

**La solución que sí les da lo mejor de ambos mundos:** una tabla `transacciones` única y normalizada, más **vistas de base de datos** (`VIEW`) llamadas `vista_ingresos` y `vista_egresos` que filtran automáticamente. Así, cuando ustedes o el LLM necesiten consultar "solo ingresos", consultan la vista y se comporta como si fuera una tabla separada — pero por debajo sigue habiendo una sola fuente de verdad.

```sql
CREATE VIEW vista_ingresos AS
  SELECT * FROM transacciones WHERE tipo = 'ingreso';

CREATE VIEW vista_egresos AS
  SELECT * FROM transacciones WHERE tipo = 'egreso';
```

Con esto, la sensación de "tener tablas separadas" para trabajar más claro sí la tienen, sin pagar el costo de mantenimiento de datos duplicados.

### `negocios`
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| nombre | text | |
| rubro | text | Detectado o declarado (ej. tienda, comedor, taller) |
| regimen_tributario | text | Opcional |
| creado_en | timestamp | |

### `usuarios`
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| negocio_id | uuid (FK) | |
| telefono / canal | text | Para vincular WhatsApp u otro canal |
| rol | text | dueño, empleado, etc. |

### `cuentas_dinero`
Dónde vive el dinero. Sin esto no se puede saber cuánto efectivo real tiene el negocio, solo el total de movimientos.
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| negocio_id | uuid (FK) | |
| nombre | text | "Efectivo", "Cuenta banco X", "Billetera digital" |
| tipo | enum | efectivo / banco / digital |
| saldo_actual | numeric(12,2) | Se recalcula con cada transacción o vía trigger |

### `categorias`
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| negocio_id | uuid (FK, nullable) | null = categoría global del sistema |
| categoria_padre_id | uuid (FK, nullable) | nivel 1 al que pertenece (las 8 de la Parte 1) |
| nombre | text | |
| tipo | enum | ingreso / egreso |

### `transacciones` (tabla central, ver nota de diseño arriba)
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| negocio_id | uuid (FK) | |
| cuenta_dinero_id | uuid (FK) | Qué cuenta se afectó |
| categoria_id | uuid (FK) | |
| monto | numeric(12,2) | |
| tipo | enum | ingreso / egreso |
| descripcion_original | text | El texto/transcripción tal como llegó |
| descripcion_normalizada | text | Lo que la IA interpretó |
| fecha | date | |
| origen | enum | voz, texto, manual |
| confianza_clasificacion | numeric | Score del modelo (para saber cuándo pedir confirmación) |
| confirmado_por_usuario | boolean | Clave para su métrica de precisión algorítmica |
| prestamo_id | uuid (FK, nullable) | Solo si esta transacción pertenece a un préstamo |
| inversion_id | uuid (FK, nullable) | Solo si esta transacción es la compra de un activo |
| sincronizado | boolean | Para el manejo offline (Parte 0) |
| creado_en | timestamp | |

### `prestamos`
Los préstamos necesitan datos que una transacción simple no tiene (tasa, plazo, saldo pendiente), por eso llevan su propia tabla ligada a la transacción de desembolso.
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| negocio_id | uuid (FK) | |
| entidad_prestamista | text | Banco, cooperativa, persona |
| monto_total | numeric(12,2) | |
| tasa_interes | numeric | |
| plazo_meses | int | |
| saldo_pendiente | numeric(12,2) | Se recalcula con cada cuota pagada |
| fecha_inicio | date | |

### `inversiones`
Similar razonamiento: un activo tiene datos propios (vida útil, depreciación) que no caben bien en una transacción genérica.
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| negocio_id | uuid (FK) | |
| descripcion | text | |
| valor_adquisicion | numeric(12,2) | |
| vida_util_meses | int | Opcional, si quieren calcular depreciación |
| fecha_adquisicion | date | |

### `conversaciones` (log de interacción, útil para mejorar el NLU y para la tesis)
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid (PK) | |
| usuario_id | uuid (FK) | |
| mensaje_usuario | text | |
| intencion_detectada | enum | conversacional / transaccional / consulta_reporte |
| respuesta_sistema | text | |
| transaccion_id | uuid (FK, nullable) | Si derivó en un registro |
| creado_en | timestamp | |

Esta tabla `conversaciones` es la que les permitirá, más adelante, justificar con datos reales la tasa de precisión algorítmica y el nivel de adopción que mencionan como indicadores de éxito.

### Relaciones, en resumen
`negocios` (1) → (N) `usuarios`, `cuentas_dinero`, `categorias`, `transacciones`, `prestamos`, `inversiones`
`transacciones` (N) → (1) `categorias`, `cuentas_dinero`, y opcionalmente (1) `prestamos` o `inversiones`
`conversaciones` (N) → (1) `usuarios`, y opcionalmente (1) `transacciones`

---

## Parte 3: Plan de prototipado por fases

Enfocado en lo que pidieron: primero validar el ciclo **voz → texto visible → IA → respuesta correcta según intención**, antes de construir dashboard o persistencia completa.

### Fase 0 — Preparación (1 semana)
**Objetivo:** dejar el entorno listo sin lógica de negocio aún.
- Elegir stack final (Flutter o React Native + Supabase, según lo discutido)
- Configurar proyecto móvil base y conexión a un servicio de voz-a-texto
- Configurar acceso a la API del LLM elegido con salida estructurada (JSON)

**Criterio de éxito:** la app puede grabar audio y mostrar cualquier texto en pantalla (aunque sea "hola mundo").

---

### Fase 1 — Voz a texto + visualización (prioridad que pidieron)
**Objetivo:** capturar audio del usuario, transcribirlo, y mostrarlo en pantalla tal cual se detectó, **sin IA todavía**.
- Botón de grabar/detener
- Envío del audio a Whisper o al STT nativo del dispositivo
- Mostrar el texto transcrito en una burbuja tipo chat, editable por el usuario (por si el STT se equivocó)

**Criterio de éxito:** el usuario habla, ve el texto exacto detectado, y puede corregirlo antes de continuar. Esto es importante como paso de control de calidad — no avanzar a la IA con una transcripción que el usuario no validó.

---

### Fase 2 — Enrutamiento de intención + respuesta de la IA (el corazón de lo que preguntan)
**Objetivo:** que el texto (ya transcrito/validado) se envíe a la IA, y que el sistema decida **si es conversación o si debe producir un dato formateado**.

Esto se resuelve con un solo llamado al LLM pidiéndole que **siempre** devuelva una salida estructurada con un campo de tipo, por ejemplo:

```json
{
  "tipo_respuesta": "transaccion" | "conversacion" | "consulta_reporte",
  "mensaje_para_usuario": "texto de respuesta natural",
  "datos_transaccion": {
    "monto": 200,
    "categoria_sugerida": "venta de producto",
    "tipo": "ingreso",
    "confianza": 0.92
  }
}
```

- Si `tipo_respuesta = "transaccion"` → la app muestra una tarjeta de confirmación con los datos extraídos ("Detecté: ingreso de Q200 por venta de producto. ¿Confirmas?")
- Si `tipo_respuesta = "conversacion"` → la app solo muestra `mensaje_para_usuario` como chat normal (ej. el usuario preguntó algo, saludó, o dio información ambigua)
- Si `tipo_respuesta = "consulta_reporte"` → se deja preparado el gancho para fases posteriores (dashboard), aunque en esta fase puede devolver solo un mensaje de "función aún no disponible"

**Criterio de éxito:** probar con al menos 15-20 frases reales y variadas (formales, coloquiales, ambiguas, saludos, preguntas) y medir cuántas veces el enrutamiento (`tipo_respuesta`) fue el correcto. Este dato ya les sirve como primer insumo real para su indicador de "precisión algorítmica".

---

### Fase 3 — Confirmación y persistencia estructurada
**Objetivo:** una vez que el usuario confirma la tarjeta de la Fase 2, guardar el registro en las tablas propuestas en la Parte 2.
- Guardar en `transacciones` con `confirmado_por_usuario = true`
- Guardar también el log en `conversaciones` (haya derivado en transacción o no)
- Manejar el caso "el usuario corrige la categoría antes de confirmar" (esto retroalimenta al catálogo `categorias` si crean una nueva)

**Criterio de éxito:** el ciclo completo funciona de punta a punta: habla → transcribe → clasifica → confirma → se guarda en base de datos real.

---

### Fase 4 — Dashboard dinámico (server-driven UI)
**Objetivo:** ya con datos reales acumulados, activar el motor de composición que discutimos antes — seleccionar qué widgets mostrar según el patrón de transacciones del negocio.
- Reglas simples al inicio (ej. "si hay más de X transacciones de un tipo, mostrar el widget de esa categoría") antes de intentar algo más sofisticado
- Widgets ya construidos: flujo de caja, gastos por categoría, alertas de gasto excesivo

**Criterio de éxito:** dos negocios distintos (ej. una tienda vs. un comedor) terminan viendo combinaciones distintas de widgets sin que nadie haya programado esa diferencia manualmente.

---

## Nota sobre orden de trabajo
Dado lo que priorizaron en su mensaje, el orden natural es **Fase 1 → Fase 2 primero**, incluso antes de tener el esquema de base de datos 100% cerrado — pueden probar el ciclo voz→texto→clasificación con datos "de mentira" (mock) mientras terminan de investigar los estándares contables. La Parte 1 (catálogo) alimenta directamente los `categoria_sugerida` que la IA debe devolver en la Fase 2, así que sí conviene tener al menos el nivel 1 (las 8 categorías fijas) definido antes de empezar esa fase.