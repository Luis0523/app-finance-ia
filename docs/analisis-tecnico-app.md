# Análisis técnico de Lumina Finance (`finanzas_ia`)

> Documento generado a partir del código fuente, el esquema SQL, `pubspec.yaml`/`pubspec.lock` y la documentación del repositorio.
> Fecha de análisis: 2026-10-31.

---

## 1. Resumen ejecutivo

**Lumina Finance** es una aplicación móvil para microempresarios guatemaltecos que permite registrar ingresos, egresos, inventario, ventas de punto de venta, fiados y proveedores usando **lenguaje natural por voz o texto**. La app interpreta la frase con un LLM, propone una transacción, el usuario la confirma y el sistema la guarda en **Supabase/Postgres**, aplicando contabilidad simplificada y costeo de inventario por **costo promedio ponderado (CPP)**.

- **Nombre técnico del paquete:** `finanzas_ia`
- **Nombre visible en la app:** `Lumina Finance`
- **Versión:** `1.0.0+1`
- **Plataforma principal:** Android (APK generado en `build/app/outputs/flutter-apk/app-debug.apk`)
- **Plataformas configuradas en el proyecto:** Android, iOS y Web (el desarrollo y las validaciones documentadas se centran en Android)
- **Idioma de la interfaz y del asistente:** español
- **Moneda:** quetzal guatemalteco (Q / GTQ)
- **Backend:** Supabase (Postgres + RPC + Storage + RLS)
- **IA:** DeepSeek `deepseek-chat` por defecto; OpenAI `gpt-4o-mini` como alternativa
- **Arquitectura:** Flutter + Riverpod + Repository Pattern + Supabase

El proyecto nació como prototipo de tesis universitaria en Quetzaltenango, Guatemala, y evolucionó por fases: captura de voz, clasificación con IA, persistencia, reportes, inventario/kardex, proveedores, POS y cuaderno de fiados.

---

## 2. Problema que resuelve

Los microempresarios suelen no llevar contabilidad formal porque hacerlo manualmente es complejo. La app reduce la captura a hablarle al teléfono:

1. El usuario dice o escribe algo como *“vendí Q200 de fruta hoy”*.
2. La app transcribe voz a texto (si aplica) y permite editar.
3. El LLM clasifica la intención y extrae monto, tipo, categoría, cantidad y producto.
4. La app muestra una tarjeta de confirmación editable.
5. Al confirmar, se guarda en `transacciones` y, si corresponde, se afecta inventario, kardex y utilidad.

Además del registro conversacional, la app ofrece módulos visuales para operar el negocio: dashboard, POS con escáner, stock, historial, proveedores y fiados.

---

## 3. Stack tecnológico y versiones

### 3.1 Núcleo

| Componente | Tecnología | Versión real en el proyecto |
|---|---|---|
| SDK móvil | Flutter | **3.47.0** (canal stable) |
| Lenguaje | Dart | **3.13.0** |
| SDK declarado en `pubspec.yaml` | `environment.sdk` | `^3.13.0` |
| Manejo de estado | `flutter_riverpod` | **2.6.1** (declarado `^2.5.1`) |
| Backend / BaaS | Supabase | `supabase_flutter` **2.17.2**, `supabase` **2.16.1** |
| Base de datos | PostgreSQL (Supabase) | Gestionado por Supabase |
| Cliente HTTP | `dio` | **5.11.0** |
| Voz a texto | `speech_to_text` | **7.4.0** |
| Permisos nativos | `permission_handler` | **11.4.0** |
| Variables de entorno | `flutter_dotenv` | **5.2.1** |
| Identificadores | `uuid` | **4.6.0** |
| Fechas / formato | `intl` | **0.19.0** |
| Imágenes | `image_picker` | **1.2.3** |
| Enlaces externos | `url_launcher` | **6.3.2** |
| Escaneo de códigos | `mobile_scanner` | **7.4.0** |
| Lints | `flutter_lints` | **6.0.0** |

### 3.2 Configuración nativa

| Elemento | Valor |
|---|---|
| Android `applicationId` / `namespace` | `com.finanzasia.finanzas_ia` |
| Java / Kotlin JVM target | **17** |
| Android `compileSdk`, `minSdk`, `targetSdk` | Valores por defecto de Flutter (`flutter.compileSdkVersion`, `flutter.minSdkVersion`, `flutter.targetSdkVersion`) |
| Android `versionCode` / `versionName` | Desde `pubspec.yaml`: `1` / `1.0.0` |
| Permisos Android declarados | `RECORD_AUDIO`, `CAMERA` |
| iOS deployment target | **15.0** |
| iOS `NSMicrophoneUsageDescription` | Configurado |
| iOS cámara / fotos | **No se encontraron** `NSCameraUsageDescription` ni `NSPhotoLibraryUsageDescription` en `Info.plist` |
| Web | Scaffold presente (`web/`) con título genérico `finanzas_ia` |

### 3.3 Servicios externos

| Servicio | Uso |
|---|---|
| **Supabase** | Postgres, RPCs, RLS y Storage. URL configurada en `.env` (proyecto `igiplikyrdjsupklrmdx`). |
| **DeepSeek API** | Clasificación NLU y análisis financiero. Endpoint `https://api.deepseek.com`, modelo `deepseek-chat`. |
| **OpenAI API** | Alternativa opcional. Endpoint `https://api.openai.com/v1`, modelo `gpt-4o-mini`. |
| **Reconocimiento de voz del sistema** | `speech_to_text` usa el motor nativo del dispositivo; no pasa por un servidor propio. |

---

## 4. Arquitectura del sistema

### 4.1 Vista general

```text
┌─────────────────────────────────────────────────────────────┐
│                    App Flutter (Android/iOS)                │
│                                                             │
│  Screens (UI)                                               │
│    Inicio · POS · Asistente · Stock · Historial             │
│    Proveedores · Cuaderno de Fiados · Gráficas              │
│                                                             │
│  Providers (Riverpod)                                       │
│    dashboard · chat · speech · pos · inventario · fiados    │
│    proveedores · categorías · negocio · supabase            │
│                                                             │
│  Services                                                   │
│    LlmService (Dio → DeepSeek/OpenAI)                       │
│    SpeechService (motor nativo)                             │
│    SupabaseRepository (RPC/tablas/Storage)                  │
│                                                             │
│  Models                                                     │
│    Transacciones, inventario, kardex, fiados, proveedores…  │
└───────────────┬───────────────────────────┬─────────────────┘
                │ HTTPS                     │ HTTPS
                ▼                           ▼
┌───────────────────────────┐   ┌─────────────────────────────┐
│  DeepSeek / OpenAI API    │   │  Supabase                    │
│  - Clasificación con      │   │  - Postgres                  │
│    function calling       │   │  - RPCs (PL/pgSQL/SQL)       │
│  - Análisis financiero    │   │  - Triggers de inventario    │
└───────────────────────────┘   │  - RLS                       │
                                │  - Storage bucket productos  │
                                └─────────────────────────────┘
```

### 4.2 Capas

| Capa | Ubicación | Responsabilidad |
|---|---|---|
| **UI** | `lib/screens/` | Pantallas y widgets. Consumen providers. |
| **Estado** | `lib/providers/` | Inyección de dependencias y estado reactivo con Riverpod. |
| **Servicios** | `lib/services/` | Lógica de IA (`llm_service.dart`), configuración del proveedor (`llm_config.dart`), voz (`speech_service.dart`) y acceso a datos (`supabase_repository.dart`). |
| **Modelos** | `lib/models/` | DTOs inmutables con `fromJson`/`fromMap` y `copyWith`. |
| **Tema** | `lib/theme/lumina_theme.dart` | Sistema de diseño “Lumina Finance”: colores, radios y tipografía. |
| **Utilidades** | `lib/utils/currency.dart` | Normalización de “quetzales” a `Q`. |
| **Backend** | `supabase/*.sql` | Esquema, RPCs, triggers, RLS y seeds. |

### 4.3 Patrón de acceso a datos

`FinanzasRepository` es una interfaz abstracta (`lib/services/supabase_repository.dart`) implementada por `SupabaseRepository`. Esto permite sustituir la implementación por un `FakeRepository` en pruebas (`test/fakes/fake_repository.dart`).

La app **no usa un backend propio**: habla directamente con Supabase usando la clave publicable y con el LLM usando una API key embebida en la app.

### 4.4 Flujo de una transacción conversacional

```text
Usuario habla/escribe
        │
        ▼
SpeechService (opcional) → texto editable
        │
        ▼
ChatController.sendMessage()
        │
        ├── inserta conversación (intención tentativa)
        │
        ▼
LlmService.classify(texto, últimos 20 mensajes)
        │  POST /chat/completions
        │  tool_choice = clasificar_mensaje (forzado)
        ▼
LlmResponse { tipo_respuesta, mensaje, datos_transaccion, datos_consulta }
        │
        ├── transaccion → tarjeta de confirmación
        │       │
        │       ├── usuario corrige (monto, tipo, categoría)
        │       └── aceptar → _persistir()
        │               ├── buscar/crear categoría nivel 2
        │               ├── buscar/crear producto (si aplica)
        │               ├── insertar transacción
        │               ├── registrar compra (si es compra con producto)
        │               └── vincular conversación con transacción
        │
        ├── consulta_reporte → handler específico (totales, listado, etc.)
        │
        └── conversacion → burbuja de texto
```

---

## 5. Cómo fue construido

El proyecto se desarrolló de forma incremental, por fases, apoyándose en documentos de diseño y especificación:

- `docs/instruccions.md` — especificación de desarrollo.
- `docs/propuesta.md` — propuesta técnica y catálogo de cuentas.
- `docs/logicanegocio.md` — lógica de inventario, compras, producciones y ventas.
- `docs/estado-avances.md` — avance por fases.
- `docs/fase-8-inventario-proveedores.md` — detalle de inventario enriquecido.

### 5.1 Fases identificadas

| Fase | Contenido | Estado documentado |
|---|---|---|
| **Fase 0** | Proyecto Flutter, Supabase, esquema SQL, seed de 8 categorías. | Completada |
| **Fase 1** | Captura de voz y transcripción editable. | Completada |
| **Fase 2** | Clasificación con LLM mediante function calling y contexto. | Completada |
| **Fase 3** | Confirmación y persistencia en `transacciones` y `conversaciones`. | Completada |
| **Fase 4** | Totales del mes vía RPC `obtener_totales_mes`. | Completada |
| **Fase 5** | Última transacción y análisis con IA sobre agregados. | Completada |
| **Fase 6** | Listados, flujo de caja, inventario y viabilidad de compra. | Completada |
| **Fase 6b** | Cantidad × precio unitario, descripción normalizada, selector DeepSeek/OpenAI. | Completada |
| **Fase 7** | Inventario con kardex, CPP, ganancias, actualización de producto y ajustes. | Completada |
| **Fase 8** | Proveedores, imágenes, códigos de barras, categorías de producto, kardex por producto. | Completada |
| **Fase 9** | POS con escáner continuo, carrito, cobro y método de pago. | Completada |
| **Fase 10** | Cuaderno de fiados (cuentas por cobrar) y abonos. | Completada |

### 5.2 Historial de commits representativo

```text
4890b5b feat: implementar interfaz Lumina Finance con MainShell, dashboard, stock y mockups
b183d69 Fase 7: inventario con kardex y costo promedio ponderado, ganancia visible,
        actualizar producto y ajuste de existencias
786ef5f Fase 6c: proveedor OpenAI opcional, descripciones normalizadas y docs de avance
5376e1c Fase 6b: desglose cantidad x precio unitario en BD/listado/tarjeta + IA
        conversacional que pide confirmar montos
fc26e55 Fase 6: listado/tabla de ingresos y egresos, flujo de caja, inventario y
        viabilidad de compra + RLS por negocio
f7a911b Merge: prototipo completo (Fases 0-5)
```

Rama de trabajo observada: `feature/fase-6-detalle-flujo-inventario`, aunque el código ya incluye funcionalidades de fases posteriores.

### 5.3 Estilo de construcción

- **UI primero con mockups:** existe `mock/lumina_finance/DESIGN.md` y capturas en `mock/` que guiaron el tema visual.
- **Backend versionado como SQL incremental:** `reset_desde_cero.sql` reconstruye todo; los archivos `incremental_*.sql` agregan funcionalidades sin borrar datos.
- **Pruebas con dobles:** `FakeRepository`, `FakeLlmService` y `FakeSpeechService` permiten probar la app sin red.
- **Lógica de negocio documentada antes de programar:** especialmente el kardex y el CPP.
- **Validaciones documentadas:** `flutter analyze`, `flutter test` y `flutter build apk --debug`.

---

## 6. Funciones principales de la app

La navegación principal es un `IndexedStack` con cinco secciones y un botón central para el asistente:

```text
Inicio | POS | [Asistente] | Stock | Historial
```

Además hay pantallas secundarias: Gráficas, Proveedores y Cuaderno de Fiados.

### 6.1 Inicio / Dashboard

`lib/screens/home_screen.dart`

- Saludo con el nombre del negocio (`negocioNombreProvider`).
- Tarjeta de **balance del mes** (ingresos − egresos).
- Tarjetas de **ingresos** y **egresos** del mes.
- Gráfico de actividad del mes.
- Lista de **movimientos recientes** (últimos 6).
- Acceso a **Gráficas**.
- Alertas de **stock bajo/agotado**.
- Tarjeta de **sugerencias de pedidos a proveedores**.
- Acceso al **Cuaderno de Fiados**.
- Estados de carga, error con reintento y vacío.

### 6.2 Asistente conversacional

`lib/screens/chat_screen.dart` + `lib/providers/chat_provider.dart`

- Entrada por **micrófono** o **texto**.
- Transcripción editable antes de enviar.
- Burbujas de usuario/asistente.
- **Tarjeta de transacción** con monto, cantidad, precio unitario, tipo, categoría y confianza.
- Botones **Corregir** y **Confirmar**.
- Tarjetas de **reporte** (totales).
- Tablas dentro del chat (listados, flujo de caja, inventario, fiados).
- Indicador de escritura y manejo de errores.
- Contexto de conversación: últimos **20 mensajes**.

### 6.3 POS (Punto de Venta)

`lib/screens/pos_screen.dart`, `pos_carrito_sheet.dart`, `pos_cobro_modal.dart`, `lib/widgets/pos_scanner_modal.dart`, `lib/providers/pos_provider.dart`

- Catálogo táctil con búsqueda por nombre o código de barras.
- **Escaneo continuo** con cámara y alerta háptica.
- Filtros por categoría de producto.
- Carrito con incremento/decremento de cantidades, edición de precio y eliminación.
- Cobro en **efectivo, transferencia o tarjeta**.
- **Cálculo de vuelto** en efectivo.
- Registro de una transacción de ingreso por cada ítem vendido.
- Descuento automático de inventario mediante trigger y cálculo de utilidad con el costo congelado.
- Categoría contable `Ingresos › Ventas POS`.

### 6.4 Stock / Inventario

`lib/screens/stock_screen.dart`, `producto_detalle_modal.dart`, `operacion_stock_modal.dart`

- KPIs de inventario (productos, valor, stock bajo/agotado, etc.).
- Búsqueda por nombre, código o categoría.
- Filtros: todos, stock bajo, agotados, categorías.
- Vista de cuadrícula o lista.
- Alta y edición de productos con:
  - nombre, categoría, unidad de medida;
  - costo de compra, precio de venta, existencias;
  - stock mínimo y máximo;
  - proveedor habitual;
  - código de barras / SKU;
  - imagen por cámara, galería o URL;
  - escaneo de código de barras.
- Operaciones de **compra** y **ajuste de inventario** con motivo.
- Detalle de producto con **kardex** (últimos movimientos).
- Administración de proveedores.

### 6.5 Historial y gastos

`lib/screens/historial_screen.dart`

- Pestañas: **Todos**, **Ventas**, **Gastos**.
- Balance general del período.
- Totales de ventas y ganancia estimada.
- Total de gastos del mes.
- Registro manual de gastos con:
  - monto, descripción;
  - categoría contable (gastos operativos, costos de venta, gastos administrativos, otros gastos, retiros personales);
  - medio de pago (efectivo, transferencia, tarjeta).
- Acceso directo al Cuaderno de Fiados.

### 6.6 Gráficas

`lib/screens/charts_screen.dart`

- Resumen del mes.
- Gráfica de ingresos vs. egresos.
- Distribución por categorías.
- Visualización sin dependencias de chart externas (widgets y `CustomPainter`).

### 6.7 Proveedores

`lib/screens/proveedores_screen.dart`

- Directorio de proveedores.
- Alta, edición y baja lógica (`activo = false`).
- Datos: nombre, contacto, teléfono/WhatsApp, dirección, días de visita, notas.
- Acciones rápidas para llamar o abrir WhatsApp.
- Los proveedores se vinculan a productos y alimentan las sugerencias de pedido.

### 6.8 Cuaderno de Fiados

`lib/screens/cuaderno_fiados_screen.dart`

- Registro de deudas de clientes (`cuentas_por_cobrar`).
- Búsqueda y filtros: pendientes, todos, pagados.
- Registro de **abonos** y **liquidación total**.
- Actualización automática de saldo y estado (`pendiente`, `parcial`, `pagado`) mediante trigger.
- El abono también se registra como ingreso en caja.
- Acceso conversacional mediante la IA.

---

## 7. Inteligencia artificial: cómo funciona

### 7.1 Proveedor y configuración

`lib/services/llm_config.dart` selecciona el proveedor según `LLM_PROVIDER`:

- **DeepSeek (por defecto):** `LLM_API_KEY`, `LLM_BASE_URL=https://api.deepseek.com`, `LLM_MODEL=deepseek-chat`.
- **OpenAI:** `LLM_PROVIDER=openai`, `OPENAI_API_KEY`, `OPENAI_BASE_URL=https://api.openai.com/v1`, `OPENAI_MODEL=gpt-4o-mini`.

### 7.2 Contrato de clasificación

`LlmService.classify()` llama a `POST /chat/completions` con:

- `temperature: 0.2`
- `max_tokens: 1024`
- `tools: [clasificar_mensaje]`
- `tool_choice` **forzado** a la función `clasificar_mensaje`
- Hasta **2 reintentos** (3 intentos) con espera progresiva de 600 ms y 1200 ms.
- Timeouts: conexión 20 s, recepción 45 s.

La función exige esta estructura:

```json
{
  "tipo_respuesta": "transaccion | conversacion | consulta_reporte",
  "mensaje_para_usuario": "texto natural",
  "datos_transaccion": {
    "monto": 0,
    "tipo": "ingreso | egreso",
    "categoria_nivel1_sugerida": "",
    "categoria_nivel2_sugerida": "",
    "confianza": 0.0,
    "descripcion_normalizada": "",
    "cantidad": null,
    "precio_unitario": null,
    "producto_sugerido": "",
    "accion_inventario": "compra | venta | produccion",
    "confianza_inventario": 0.0
  },
  "datos_consulta": {
    "tipo_consulta": "…",
    "tipo_reporte": "ingresos | egresos | ambos",
    "tipo": "ingreso | egreso",
    "periodo": "hoy | mes_actual | mes_pasado",
    "categoria_nivel1": null,
    "monto": null,
    "producto": null,
    "precio_venta": null,
    "precio_compra": null,
    "stock_minimo": null,
    "cantidad_objetivo": null,
    "cliente": null,
    "descripcion": null
  }
}
```

### 7.3 Reglas del prompt del sistema

El prompt (`LlmService.systemPrompt`) instruye al modelo a:

- Actuar como asistente financiero para microempresarios guatemaltecos.
- Usar siempre la herramienta `clasificar_mensaje`.
- Clasificar transacciones, conversación o consultas de reporte.
- Extraer `cantidad` y `precio_unitario` y calcular `monto = cantidad × precio_unitario`.
- Redactar `mensaje_para_usuario` breve y amable, confirmando el desglose.
- Generar `descripcion_normalizada` sin montos, cantidades ni precios.
- Identificar `producto_sugerido`, `accion_inventario` y `confianza_inventario` cuando haya producto y cantidad claros.
- **No** registrar como transacción si falta el monto; en su lugar, preguntar.
- Usar el historial previo para resolver referencias como “y esto” o “esa fruta”.

### 7.4 Análisis financiero

`LlmService.analizar()` usa un segundo prompt:

- **Análisis general** (`analisisPrompt`): balance, ingresos vs. egresos, categorías relevantes, riesgos y recomendación. `temperature: 0.6`, `max_tokens: 600`.
- **Viabilidad de compra** (`viabilidadPrompt`): evalúa un plan de compra contra el resumen del mes y el valor del inventario.

El resumen enviado al LLM se construye en la app a partir de datos agregados de Supabase; no se envían transacciones individuales completas, salvo el historial de chat.

### 7.5 Extracción robusta de JSON

`_extraerJson()` tolera:

- texto envolvente antes o después del JSON;
- bloques Markdown con ```;
- respuestas vía `tool_calls` o vía `content`.

### 7.6 Normalización de moneda

`normalizeCurrencyText()` reemplaza expresiones como “200 quetzales” por “Q200” para mantener consistencia visual.

---

## 8. Qué se le puede preguntar o pedir a la IA

La IA distingue tres intenciones principales y catorce subtipos de consulta.

### 8.1 Registrar transacciones

| Ejemplo de frase | Resultado esperado |
|---|---|
| “Vendí Q200 de fruta hoy” | Ingreso, categoría de ingresos, monto Q200. |
| “Compré 340 bananos a 10 quetzales cada uno” | Egreso, cantidad 340, precio unitario Q10, monto Q3,400, producto “Bananos”, acción “compra”. |
| “Pagué Q150 de luz” | Egreso, gasto operativo. |
| “Compré Q500 de mercadería” | Egreso, costo de venta o inventario según contexto. |
| “Fié Q65 de abarrotes a Doña Carmen” | Registro en el Cuaderno de Fiados. |
| “Doña Carmen me vino a pagar Q50” | Abono a la cuenta de fiado y ingreso a caja. |
| “Me prestaron Q5,000” | Egreso/ingreso según categoría de préstamo. |
| “Retiré Q300 para mí” | Retiro personal. |

Si falta el monto o datos clave, la IA **no guarda Q0.00**: cambia a conversación y pregunta lo que falta.

### 8.2 Consultas de reportes y análisis

| Tipo interno | Ejemplos de preguntas | Qué devuelve |
|---|---|---|
| `totales` | “¿Cuánto vendí este mes?”, “¿cuánto gasté?”, “dame los totales” | Tarjeta con ingresos, egresos, balance y cantidades. |
| `ultima_transaccion` | “¿Cuál fue mi última venta?”, “¿cuál fue mi último gasto?” | Monto, categoría y fecha de la última transacción. |
| `listado` | “Muéstrame mis ingresos”, “lista mis egresos”, “mis movimientos” | Tabla con fecha, categoría, descripción, cantidad, costo unitario, total y ganancia. |
| `flujo_caja` | “¿Cómo va mi flujo de caja?”, “¿cómo se movió el dinero este mes?” | Tabla por día con ingresos, egresos y balance. |
| `analisis` | “¿Qué tal ves mi balance?”, “¿cómo voy?”, “analízame” | Análisis breve generado por el LLM. |
| `viabilidad` | “¿Puedo comprar Q5,000 de mercadería?”, “¿es viable comprar un freezer?” | Evaluación con balance, ingresos e inventario. |
| `inventario` | “¿Cuántos bananos tengo?”, “muéstrame mi inventario”, “¿qué producto se está acabando?” | Tabla de existencias, costo, valor, ganancia y estado. |
| `ganancias` | “¿Cuánto gané este mes?”, “¿cuál es mi margen?”, “¿me conviene vender?” | Ventas, costo de lo vendido, ganancia y margen. |
| `cuentas_por_cobrar` | “¿Quiénes me deben dinero?”, “¿cuánto me debe Doña Carmen?”, “muéstrame los fiados” | Tabla de deudas pendientes con saldo y atraso. |
| `pedidos_proveedor` | “¿Qué le tengo que pedir a los proveedores?”, “¿quién me visita hoy?”, “sugerencias de surtido” | Sugerencias agrupadas por proveedor, con cantidades y costo estimado. |

### 8.3 Comandos de inventario

| Tipo interno | Ejemplos | Acción |
|---|---|---|
| `actualizar_producto` | “Actualiza el precio de venta de gaseosas a 5”, “cambia el precio de compra a 3”, “configura stock mínimo de bananos en 10” | RPC `actualizar_producto`. |
| `ajustar_inventario` | “Corrige el inventario de gaseosas a 50”, “ahora hay 200 bananos”, “pon las existencias en 30” | RPC `ajustar_inventario` / `ajustar_inventario_con_motivo`. |
| `registrar_fiado` | “Fíale Q65 de abarrotes a Doña Carmen”, “apunta un fiado de Q40 a Don Pedro” | Inserta en `cuentas_por_cobrar`. |
| `abonar_fiado` | “Registra un abono de Q30 de Don Pedro”, “me pagó Q20 Don Mario” | Inserta abono, actualiza saldo y registra ingreso. |

### 8.4 Límites actuales de la IA

- El campo `periodo` se declara en el contrato, pero los handlers de la app **no lo usan**: la mayoría de consultas operan sobre el **mes actual**.
- No hay consultas por rango de fechas arbitrario ni comparación entre meses.
- No hay memoria persistente entre sesiones; el contexto es la conversación en memoria (máximo 20 mensajes).
- La IA puede equivocarse en categoría o producto; por eso existe confirmación y corrección manual.
- El análisis y la viabilidad dependen de que el LLM respete los números del resumen; el prompt prohíbe inventarlos, pero no es una garantía matemática.
- No hay function calling para ejecutar SQL arbitrario: la app mapea tipos de consulta a handlers concretos.

---

## 9. Backend y base de datos

### 9.1 Proyecto Supabase

- URL: definida en `.env` como `SUPABASE_URL`.
- Clave usada por la app: `SUPABASE_ANON_KEY` (clave publicable).
- El repositorio incluye `supabase/.temp/linked-project.json` y `supabase/.temp/cli-latest` para el CLI.

### 9.2 Tablas

| Tabla | Propósito |
|---|---|
| `negocios` | Datos del negocio. |
| `usuarios` | Usuarios del negocio (sin autenticación real). |
| `cuentas_dinero` | Efectivo, banco, digital. |
| `categorias` | Jerarquía de 2 niveles; nivel 1 global y nivel 2 por negocio. |
| `prestamos` | Préstamos y financiamiento. |
| `inversiones` | Inversiones del negocio. |
| `productos` | Catálogo con precios, stock mínimo/máximo, código, imagen, proveedor, tipo (reventa/fabricado). |
| `transacciones` | Tabla financiera central. |
| `inventario` | Foto actual por producto: existencia, costo promedio y valor generado. |
| `movimientos_inventario` | Kardex auditable de entradas, salidas y ajustes. |
| `compras` | Entradas de inventario comprado. |
| `producciones` | Entradas de inventario fabricado con receta. |
| `producto_costos` | Receta de insumos para productos fabricados. |
| `conversaciones` | Log de interacciones para métricas. |
| `proveedores` | Directorio de proveedores. |
| `cuentas_por_cobrar` | Fiados / deudas de clientes. |
| `abonos_cuentas_cobrar` | Abonos parciales o totales. |

### 9.3 Enums

```sql
tipo_movimiento: ingreso | egreso
origen_transaccion: voz | texto | manual
tipo_cuenta_dinero: efectivo | banco | digital
tipo_intencion: conversacional | transaccional | consulta_reporte
tipo_movimiento_inventario: compra | produccion | venta | ajuste
```

### 9.4 Funciones RPC usadas por la app

| RPC | Uso |
|---|---|
| `buscar_o_crear_producto` | Crea o recupera un producto por nombre normalizado. |
| `obtener_inventario` | Inventario enriquecido con proveedor, imagen, costo, valor y estado. |
| `obtener_totales_mes` | Ingresos, egresos y cantidades del mes. |
| `obtener_ultima_transaccion` | Última transacción confirmada, opcionalmente filtrada por tipo. |
| `obtener_resumen_analisis` | Totales + desglose por categoría. |
| `obtener_listado_transacciones` | Listado con cantidad, precio, costo congelado y utilidad. |
| `obtener_resumen_ganancias` | Ventas, costo de ventas, utilidad y margen. |
| `obtener_flujo_caja` | Ingresos/egresos/balance por día del mes. |
| `actualizar_producto` | Actualiza precio de venta, compra o stock mínimo por nombre. |
| `ajustar_inventario` | Ajusta existencias por nombre. |
| `actualizar_producto_por_id` | Actualización completa por ID (incluye nombre, imagen, código, proveedor). |
| `ajustar_inventario_con_motivo` | Ajuste con motivo y registro en kardex. |
| `obtener_kardex_producto` | Últimos movimientos de un producto. |

### 9.5 Triggers

| Trigger | Función |
|---|---|
| `trg_chk_tipo_categoria` | Valida que la subcategoría tenga el mismo tipo que el padre. |
| `trg_registrar_compra` | Suma existencia, recalcula CPP e inserta movimiento de kardex. |
| `trg_registrar_produccion` | Calcula costo unitario del lote, suma existencia, recalcula CPP e inserta kardex. |
| `trg_registrar_venta_inventario` | Descuenta inventario, congela `costo_unitario_momento_venta` y calcula `utilidad_calculada`. |
| `trg_actualizar_saldo_cuenta_cobrar` | Recalcula saldo y estado del fiado al insertar/editar/borrar abonos. |

### 9.6 Vistas

- `vista_ingresos`
- `vista_egresos`

### 9.7 Seeds

`reset_desde_cero.sql` crea:

- Las **8 categorías de nivel 1**: Ingresos, Costos de venta, Gastos operativos, Gastos administrativos, Otros gastos, Inversiones, Préstamos y financiamiento, Retiros personales.
- Un negocio de prueba: `Tienda de Doña María`.
- Un usuario de prueba.
- Una cuenta de efectivo.

---

## 10. Lógica contable y de inventario

### 10.1 Costo promedio ponderado (CPP)

Cada compra o producción recalcula el costo promedio:

```text
nuevo_costo_promedio =
  (existencia_actual × costo_promedio_actual + cantidad_nueva × costo_unitario_nuevo)
  ÷ (existencia_actual + cantidad_nueva)
```

Cada venta:

1. Usa el costo promedio vigente.
2. Lo **congela** en `transacciones.costo_unitario_momento_venta`.
3. Calcula `utilidad_calculada = monto − costo_promedio × cantidad`.

Esto evita que los reportes históricos cambien cuando cambian los costos futuros.

### 10.2 Tres momentos del producto

| Momento | Tabla | Efecto |
|---|---|---|
| **Compra** | `compras` | Entrada de inventario comprado a proveedor. |
| **Producción** | `producciones` + `producto_costos` | Entrada de inventario fabricado con receta. |
| **Venta** | `transacciones` tipo ingreso con `producto_id` | Salida de inventario y utilidad real. |

`producto_costos` solo se usa para calcular el costo de un lote producido; **no** se usa para calcular la utilidad de cada venta.

### 10.3 Fuente de verdad

- `inventario` es la fuente de verdad de “cuánto tengo y a qué costo”.
- `movimientos_inventario` es el kardex auditable que explica cómo se llegó a ese número.
- `transacciones` es la fuente principal de la información financiera.

---

## 11. Seguridad

> Esta sección describe el estado **actual** del prototipo. Varios puntos son aceptables para una demo interna, pero **no para producción ni para datos reales de emprendedores**.

### 11.1 Autenticación y autorización

| Punto | Estado actual | Riesgo |
|---|---|---|
| Autenticación de usuarios | **No existe**. No hay login, registro ni sesión de Supabase Auth. | Cualquiera con la app y la clave publicable puede operar. |
| Identificación del negocio | Se usa el **primer negocio sembrado** y se envía un header `x-negocio-id`. | No hay vínculo entre usuario real y negocio. |
| RLS | Activo en las tablas, basado en `session_negocio_id()`, que lee `request.headers -> 'x-negocio-id'`. | El header lo controla el cliente: puede cambiarse por otro `negocio_id`. |
| Políticas con `or session_negocio_id() is null` | Presentes en `proveedores`, `cuentas_por_cobrar` y `abonos_cuentas_cobrar`. | Si no se envía el header, la política permite acceso a **todas** las filas. |
| `negocios` | Política de lectura `using (true)` para `anon`. | Permite enumerar todos los negocios y obtener sus IDs. |
| Funciones `security definer` | Varias RPC reciben `p_negocio_id` sin validar que pertenezca al llamante. | Un cliente podría invocarlas con otro `negocio_id` y operar sobre datos ajenos. |
| Permisos | `grant all on all tables in schema public to anon, authenticated`. | Superficie de ataque amplia. |

**Conclusión:** la RLS actual **no es una frontera de seguridad real** mientras el negocio se identifique con un header controlado por el cliente y no con un JWT firmado por Supabase Auth.

### 11.2 Secretos y claves

| Secreto | Ubicación | Riesgo |
|---|---|---|
| `SUPABASE_ANON_KEY` | `.env`, incluido como asset en el APK. | Es una clave publicable; su exposición es esperada, pero depende de que RLS sea correcta. Hoy no lo es. |
| `LLM_API_KEY` / `OPENAI_API_KEY` | `.env`, incluido como asset en el APK. | **Clave secreta facturable embebida en el cliente**. Puede extraerse del APK y usarse para consumir la cuenta. |
| `.env` en el repositorio | Está en `.gitignore` y **no** aparece en `git ls-files`. | Bien: no se versiona. Aun así, existe en disco y se empaqueta en la app. |

**Recomendación inmediata:** rotar las claves de LLM si el APK o el `.env` se compartieron, y mover las llamadas al LLM a un backend/Edge Function.

### 11.3 Datos y privacidad

- La app envía al proveedor de LLM el texto del usuario y hasta **20 mensajes previos** de la conversación. Eso incluye información financiera del negocio.
- El proveedor recibe también montos, categorías y productos detectados.
- Las imágenes de productos se suben a un bucket público `productos` y se devuelve una URL pública.
- No se observa cifrado adicional en el cliente; el transporte es HTTPS.
- No hay política de retención ni borrado de conversaciones.

### 11.4 Superficie de ataque y buenas prácticas ausentes

- Sin rate limiting en RPCs ni en el LLM.
- Sin validación de pertenencia del `negocio_id` en RPCs `security definer`.
- Sin `search_path` fijado en funciones `security definer`.
- Sin idempotencia en el registro de transacciones (doble tap podría duplicar).
- Sin firma de release: `build.gradle.kts` usa la **clave de debug** para `release`.
- Sin certificado pinning ni ofuscación.
- Sin autenticación en Storage; el bucket `productos` se usa como público.
- Sin auditoría de accesos ni logs de seguridad.
- Sin política de contraseñas porque no hay autenticación.

### 11.5 Recomendaciones priorizadas

1. **Implementar Supabase Auth** (email/OTP o teléfono) y derivar `negocio_id` de un claim del JWT, no de un header.
2. **Reescribir las políticas RLS** usando `auth.uid()` / `auth.jwt()` y eliminar el fallback `session_negocio_id() is null`.
3. **Eliminar el header `x-negocio-id`** como fuente de autorización.
4. **Mover el LLM a una Edge Function o backend propio** con la API key en el servidor, rate limiting y validación de sesión.
5. **Revisar las RPC `security definer`**: validar que `p_negocio_id` pertenezca al usuario autenticado y fijar `search_path`.
6. **Restringir permisos**: quitar `grant all` a `anon`; otorgar solo lo necesario.
7. **Configurar Storage con políticas** y decidir si las imágenes deben ser públicas.
8. **Firmar el release** con una keystore propia.
9. **Agregar idempotencia** a la creación de transacciones y ventas POS.
10. **Documentar privacidad**: qué se envía al LLM, retención y consentimiento.

---

## 12. Configuración y ejecución

### 12.1 Variables de entorno

```env
# Supabase
SUPABASE_URL=https://<proyecto>.supabase.co
SUPABASE_ANON_KEY=<clave publicable>

# DeepSeek (por defecto)
LLM_PROVIDER=deepseek
LLM_API_KEY=<api key>
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-chat

# OpenAI (alternativa)
# LLM_PROVIDER=openai
OPENAI_API_KEY=<api key>
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
```

El archivo `.env` se declara como asset en `pubspec.yaml`, por lo que **se empaqueta dentro del APK**.

### 12.2 Puesta en marcha

```bash
flutter pub get
# crear .env con las claves
# ejecutar supabase/reset_desde_cero.sql en el SQL Editor de Supabase
# ejecutar los incrementales según el estado de la base:
#   incremental_actualizar_producto.sql
#   incremental_ganancias.sql
#   incremental_fase8_inventario_proveedores.sql
#   incremental_fase9_pos.sql
#   incremental_fase10_fiados_y_gastos.sql
flutter run
```

### 12.3 Build

```bash
flutter build apk --debug
# salida: build/app/outputs/flutter-apk/app-debug.apk
```

### 12.4 Calidad

```bash
flutter analyze
flutter test
```

El repositorio incluye **10 archivos de prueba** y alrededor de **74 declaraciones `test`/`testWidgets`**. La documentación de avances reporta `flutter analyze` sin errores, `flutter test` pasando y build APK correcto; esas cifras corresponden al momento en que se escribió cada documento.

Cobertura de pruebas observada:

- Parseo de respuestas del LLM y tool calls.
- Reintentos y errores del LLM.
- Configuración DeepSeek/OpenAI.
- Controlador de chat: envío, confirmación, corrección, contexto, errores, consultas, fiados.
- Modelos de cuentas por cobrar, abonos y proveedores.
- POS: subtotales, carrito, código de barras.
- Inventario Fase 8: proveedores, producto, kardex, ajustes.
- Utilidad/currency.
- Widget tests de navegación y chat.

---

## 13. Estructura del código

```text
lib/
├── main.dart                        # dotenv + Supabase + ProviderScope + MaterialApp
├── models/                          # 20 DTOs
│   ├── categoria.dart
│   ├── chat_message.dart
│   ├── llm_response.dart
│   ├── producto_inventario.dart
│   ├── movimiento_kardex.dart
│   ├── cuenta_por_cobrar.dart
│   ├── abono_cuenta_cobrar.dart
│   ├── proveedor.dart
│   ├── sugerencia_pedido_proveedor.dart
│   └── ...
├── providers/
│   ├── supabase_provider.dart
│   ├── chat_provider.dart
│   ├── speech_provider.dart
│   ├── dashboard_provider.dart
│   ├── pos_provider.dart
│   ├── inventario_provider.dart
│   ├── fiados_provider.dart
│   ├── proveedores_provider.dart
│   ├── categorias_provider.dart
│   └── negocio_provider.dart
├── screens/
│   ├── main_shell.dart
│   ├── home_screen.dart
│   ├── chat_screen.dart
│   ├── pos_screen.dart
│   ├── pos_carrito_sheet.dart
│   ├── pos_cobro_modal.dart
│   ├── stock_screen.dart
│   ├── producto_detalle_modal.dart
│   ├── operacion_stock_modal.dart
│   ├── historial_screen.dart
│   ├── charts_screen.dart
│   ├── proveedores_screen.dart
│   └── cuaderno_fiados_screen.dart
├── services/
│   ├── llm_service.dart
│   ├── llm_config.dart
│   ├── speech_service.dart
│   └── supabase_repository.dart
├── widgets/
│   ├── barcode_scanner_modal.dart
│   ├── pos_scanner_modal.dart
│   └── imagen_producto.dart
├── theme/lumina_theme.dart
└── utils/currency.dart

supabase/
├── reset_desde_cero.sql
├── incremental_actualizar_producto.sql
├── incremental_ganancias.sql
├── incremental_fase8_inventario_proveedores.sql
├── incremental_fase9_pos.sql
└── incremental_fase10_fiados_y_gastos.sql

test/
├── fakes/fake_repository.dart
├── chat_controller_test.dart
├── cuentas_por_cobrar_test.dart
├── currency_test.dart
├── fase8_inventario_proveedores_test.dart
├── llm_config_test.dart
├── llm_response_test.dart
├── llm_service_test.dart
├── pos_test.dart
└── widget_test.dart

docs/
├── instruccions.md
├── propuesta.md
├── logicanegocio.md
├── estado-avances.md
├── fase-8-inventario-proveedores.md
└── analisis-tecnico-app.md   ← este documento
```

---

## 14. Limitaciones conocidas

- **Sin autenticación multiusuario**: un solo negocio de prueba.
- **Sin sincronización offline robusta**: se requiere conexión a Supabase.
- **Sin dashboard dinámico configurable**.
- **Sin integración con WhatsApp**.
- **Sin notificaciones push**.
- **Sin reportes por rango de fechas arbitrario** ni comparación entre meses.
- **`periodo` no se aplica** en los handlers; casi todo es mes actual.
- **Sin gestión real de producciones desde la UI**, aunque el esquema y los triggers existen.
- **Sin recetas editables desde la app** (`producto_costos` existe en BD).
- **iOS**: faltan descripciones de uso de cámara/galería; el escaneo y la selección de imágenes podrían fallar en iOS.
- **Release Android firmado con debug**.
- **Seguridad de autorización incompleta**, como se detalla en la sección 11.
- **Dependencia fuerte de la calidad del LLM**: la categoría y el producto pueden requerir corrección manual.
- **Claves de LLM en el cliente**: riesgo de costo y abuso.

---

## 15. Roadmap técnico sugerido

### Corto plazo

1. Rotar claves expuestas y mover el LLM a una Edge Function.
2. Implementar Supabase Auth y RLS basada en JWT.
3. Corregir políticas con fallback `null`.
4. Firmar el release con keystore propia.
5. Completar permisos de iOS.
6. Agregar idempotencia a transacciones y ventas POS.

### Mediano plazo

1. Reportes por rango de fechas y comparativos mensuales.
2. Producciones y recetas desde la UI.
3. Sincronización offline con cola local.
4. Dashboard configurable.
5. Notificaciones de stock bajo y visitas de proveedores.
6. Exportación de reportes (PDF/CSV).

### Largo plazo

1. Multiusuario y multinegocio real.
2. Integración con WhatsApp.
3. Conciliación bancaria.
4. Facturación electrónica (FEL en Guatemala).
5. Analítica avanzada y proyecciones.

---

## 16. Conclusión

Lumina Finance es un prototipo funcional y bien estructurado para validar un ciclo completo: **voz/texto → clasificación con IA → confirmación → persistencia → reportes → inventario → operación del negocio**. Su mayor fortaleza es la combinación de un asistente conversacional con módulos operativos reales (POS, stock, fiados, proveedores) y una lógica contable de inventario correctamente modelada con kardex y CPP.

Su principal deuda técnica está en **seguridad y multiusuario**: la autorización actual se basa en un header controlado por el cliente, no hay autenticación y las claves del LLM viajan dentro del APK. Antes de usar la app con emprendedores reales, esos puntos deben resolverse.

---

## 17. Referencias rápidas

- Punto de entrada: `lib/main.dart:9`
- Contrato y prompts del LLM: `lib/services/llm_service.dart:44`
- Configuración DeepSeek/OpenAI: `lib/services/llm_config.dart:15`
- Orquestación del chat: `lib/providers/chat_provider.dart:98`
- Persistencia y acceso a datos: `lib/services/supabase_repository.dart:183`
- Esquema completo: `supabase/reset_desde_cero.sql`
- Lógica de inventario/CPP: `docs/logicanegocio.md`
- Estado por fases: `docs/estado-avances.md`
- Navegación principal: `lib/screens/main_shell.dart:10`
- Tema visual: `lib/theme/lumina_theme.dart`
- Pruebas: `test/`
