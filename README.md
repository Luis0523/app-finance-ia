# Asistente Financiero Conversacional para Microempresarios

Aplicación móvil que permite a microempresarios sin formación contable registrar sus transacciones hablando o escribiendo en su propio lenguaje cotidiano. La IA transcribe, clasifica y guarda cada movimiento en una base de datos contable simplificada.

> Proyecto de tesis universitaria (Quetzaltenango, Guatemala). Prototipo funcional para validar el ciclo: **voz → texto → clasificación con IA → confirmación → guardado en base de datos**.

---

## Problema que resuelve

Los microempresarios no llevan registro de sus movimientos de dinero porque hacer contabilidad manualmente es complejo. Este asistente reduce la captura a "hablarle" al teléfono: el usuario dice por ejemplo *"vendí Q200 de fruta hoy"*, y el sistema:

1. Transcribe la voz a texto (editable por el usuario).
2. Clasifica la transacción con un LLM (ingreso/egreso, monto, categoría).
3. Muestra una tarjeta de confirmación con los datos detectados.
4. Guarda el registro confirmado en la base de datos.

### Categorías de nivel 1 (fijas)

Ingresos, Costos de venta, Gastos operativos, Gastos administrativos, Otros gastos, Inversiones, Préstamos y financiamiento, Retiros personales.

---

## Stack

| Componente | Tecnología |
|---|---|
| App móvil | Flutter |
| Manejo de estado | Riverpod |
| Backend / base de datos | Supabase (Postgres) |
| Voz a texto | `speech_to_text` (nativo del dispositivo) |
| Clasificación / NLU | LLM (DeepSeek / OpenAI-compatible) con function calling (JSON forzado) |
| HTTP client | `dio` |
| Variables de entorno | `flutter_dotenv` |

---

## Estado actual

| Fase | Descripción | Estado |
|---|---|---|
| **Fase 0** | Setup: proyecto Flutter, esquema SQL en Supabase, seed de 8 categorías | ✅ |
| **Fase 1** | Captura de voz y transcripción editable | ✅ |
| **Fase 2** | Envío al LLM y enrutamiento de intención (function calling con contexto) | ✅ |
| **Fase 3** | Confirmación y persistencia en Supabase (`transacciones` + `conversaciones`) | ✅ |
| **Fase 4** | Totales del mes (RPC `obtener_totales_mes`) | ✅ |
| **Fase 5** | Consultas específicas (última transacción) y análisis con IA sobre agregados por categoría | ✅ |
| **Fase 6** | Listado/tabla de ingresos y egresos, flujo de caja, inventario y análisis de viabilidad de compra | ✅ |
| **Fase 6b** | Desglose cantidad × precio unitario, descripción normalizada, selector DeepSeek/OpenAI y listados refinados | ✅ |
| **Fase 7** | Inventario con kardex, costo promedio ponderado, compras/producciones/ventas y stock conversacional | En curso |

### Criterios de aceptación por fase

- **Fase 0**: la app arranca, conecta a Supabase y muestra las 8 categorías sembradas.
- **Fase 1**: el usuario habla, ve el texto transcrito, puede editarlo y confirmarlo. Sin llamada al LLM.
- **Fase 2**: probar con al menos 15 mensajes reales y medir el acierto del enrutamiento (`tipo_respuesta`).
- **Fase 3**: el ciclo punta a punta funciona y verifica en `transacciones` y `conversaciones`.
- **Fase 4**: los totales mostrados coinciden con la suma manual de las transacciones.
- **Fase 5**: preguntas de "última venta/egreso" muestran la transacción real y "¿qué tal ves mi balance?" devuelve un análisis con IA sobre los agregados.

---

## Cómo correrlo

### Prerrequisitos

- Flutter SDK (3.x)
- Proyecto en Supabase con el esquema aplicado (ver `supabase/schema.sql`)
- API key de un LLM compatible (DeepSeek u OpenAI)

### Configuración

1. Instalar dependencias:

   ```bash
   flutter pub get
   ```

2. Crear el archivo `.env` en la raíz (no se sube al repositorio):

   ```env
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu_anon_key
   LLM_API_KEY=tu_llm_api_key
   ```

   Por defecto se usa DeepSeek (`deepseek-chat`). Para cambiar a OpenAI:

   ```env
   LLM_PROVIDER=openai
   OPENAI_API_KEY=tu_openai_api_key
   OPENAI_MODEL=gpt-4o-mini
   ```

3. Ejecutar el script `supabase/reset_desde_cero.sql` en el SQL Editor de Supabase. Este script **borra todo** y recrea el esquema desde cero aplicando la lógica de negocio de inventario (kardex + costo promedio ponderado), RLS y los seeds base.

### Ejecutar

```bash
flutter run
```

---

## Estructura del proyecto

```
lib/
├── main.dart                        # Punto de entrada (dotenv + Supabase + app)
├── models/
│   ├── categoria.dart               # Modelo de categoría
│   └── chat_message.dart            # Modelo de mensaje de chat
├── providers/
│   ├── supabase_provider.dart       # Cliente Supabase
│   ├── categorias_provider.dart     # Lectura de categorías nivel 1
│   ├── chat_provider.dart           # Mensajes y texto del campo editable
│   └── speech_provider.dart         # Estado de reconocimiento de voz
├── screens/
│   └── chat_screen.dart             # Pantalla de chat (micrófono, campo editable, enviar)
└── services/
    └── speech_service.dart          # Wrapper de speech_to_text (locale es_GT/es_ES/es_MX)
supabase/
└── schema.sql                       # Esquema de base de datos (enums, tablas, vistas, seed)
tool/
└── verify_connection.dart           # Script de verificación de conexión a Supabase
docs/
├── instruccions.md                  # Especificación de desarrollo
├── estado-avances.md                # Estado actual, avances y siguiente fase
└── propuesta.md                     # Propuesta técnica y catálogo de cuentas
```

---

## Esquema de base de datos (resumen)

- **`negocios`**, **`usuarios`**, **`cuentas_dinero`** — contexto del negocio.
- **`categorias`** — jerárquica de 2 niveles (nivel 1 global, nivel 2 por negocio), con trigger que valida consistencia de tipo padre/hijo.
- **`productos`** — catálogo con `tipo_producto` (reventa/fabricado), `unidad_medida` y `precio_venta`.
- **`inventario`** — foto actual por producto: `existencia_actual`, `costo_promedio_actual` y `valor_inventario` (generado). Única fuente de verdad de "cuánto tengo y a qué costo".
- **`movimientos_inventario`** — **kardex** auditable: cada entrada/salida con `cantidad`, `costo_unitario`, `existencia_resultante` y `costo_promedio_resultante`.
- **`compras`** — entrada de inventario comprado a proveedor (dispara el kardex con CPP).
- **`producciones`** — entrada de inventario fabricado con receta (costo = `costo_total_lote / cantidad_producida`).
- **`producto_costos`** — receta de insumos; solo se usa para calcular el costo de un lote producido.
- **`transacciones`** — tabla financiera central; en ventas se **congela** `costo_unitario_momento_venta` y se calcula `utilidad_calculada` vía trigger.
- **`prestamos`**, **`inversiones`** — tablas propias con datos específicos.
- **`conversaciones`** — log de cada interacción (para métricas de precisión de la tesis).

### Costeo de inventario

Se usa **costo promedio ponderado (CPP)**. Cada compra o producción recalcula el promedio; cada venta usa el promedio vigente y lo congela en la transacción para que reportes pasados no cambien.

---

## Nota de alcance

Este es un **prototipo**, no la app final. Fuera de alcance en esta etapa: autenticación multiusuario, sincronización offline robusta, dashboard dinámico e integración con WhatsApp.

> **Seguridad:** el esquema se crea sin Row Level Security para desarrollo interno. Antes de cualquier prueba con emprendedores reales es **obligatorio** activar RLS en Supabase con políticas por `negocio_id`.
