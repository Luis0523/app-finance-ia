# Estado y Avances del Proyecto

Fecha de actualización: 2026-08-22

## Resumen ejecutivo

La app ya cuenta con el flujo principal del prototipo: voz o texto, clasificación con IA, confirmación de la transacción, persistencia en Supabase y consultas conversacionales sobre movimientos registrados. La fase actual está cerrando la parte de transacciones detalladas y reportes básicos antes de pasar a inventario.

## Fase actual

Estamos iniciando la **Fase 7: inventario normalizado**.

Esta fase extiende la Fase 6 con mejoras de calidad sobre cómo se guardan y muestran los movimientos:

- Registro de transacciones con desglose `cantidad × precio_unitario = monto`.
- Confirmaciones conversacionales antes de guardar.
- Descripción normalizada por IA separada del mensaje de conversación.
- Listados con columnas claras: fecha, categoría real, descripción, cantidad, costo unitario y total.
- Selector de proveedor LLM entre DeepSeek y OpenAI.

## Avances completados

### Fase 0: base del proyecto

- Proyecto Flutter configurado.
- Supabase integrado.
- Esquema inicial de base de datos.
- Catálogo base de 8 categorías de nivel 1.

### Fase 1: captura de voz y texto

- Captura de voz con `speech_to_text`.
- Campo editable antes de enviar al asistente.
- Envío de mensajes de usuario al flujo de chat.

### Fase 2: clasificación con IA

- Integración con LLM usando function calling.
- Clasificación de mensajes en:
  - `transaccion`
  - `conversacion`
  - `consulta_reporte`
- Uso de historial reciente para interpretar mensajes con contexto.

### Fase 3: confirmación y persistencia

- Tarjeta de confirmación antes de guardar.
- Corrección manual de monto, tipo y categoría.
- Guardado en `transacciones`.
- Registro de interacción en `conversaciones`.

### Fase 4: totales del mes

- RPC para obtener totales mensuales.
- Respuesta conversacional para ingresos, egresos y balance.

### Fase 5: consultas y análisis

- Consulta de última transacción por tipo.
- Análisis con IA sobre agregados financieros.
- Respuestas breves orientadas a microempresarios.

### Fase 6: listados, flujo de caja y viabilidad

- Listado de ingresos, egresos y movimientos.
- Tablas visuales dentro del chat.
- Flujo de caja por día.
- Consulta básica de inventario.
- Análisis de viabilidad para compras planeadas.
- RLS por `negocio_id` en Supabase.

### Fase 6b: mejoras recientes

- Columnas `cantidad` y `precio_unitario` en transacciones.
- El LLM extrae unidades y precio unitario cuando el usuario dice frases como `compré 340 bananos a 10 quetzales cada uno`.
- El monto total se calcula como `cantidad × precio_unitario` si el LLM no lo devuelve explícitamente.
- Si falta monto o datos clave, la app no guarda Q0.00; pregunta de forma conversacional.
- `mensaje_para_usuario` queda solo para confirmar en el chat.
- `descripcion_normalizada` queda solo para listados y reportes, por ejemplo `Compra de bananos`.
- La descripción ya no repite cantidad, precio unitario ni monto porque esos datos tienen columnas propias.
- En listados, la columna `Categoría` muestra la categoría real de nivel 2, por ejemplo `Materia prima / Insumos`, no `Costos de venta › Materia prima / Insumos`.
- Soporte para cambiar proveedor LLM:
  - DeepSeek por defecto con `deepseek-chat`.
  - OpenAI como alternativa con `gpt-4o-mini`.

### Fase 7: inventario con kardex, costo promedio y ganancia

- La base de datos se reinició desde cero con `supabase/reset_desde_cero.sql` (borra todo y recrea esquema + seeds base). Se eliminaron los scripts SQL fragmentados anteriores.
- Se aplica la lógica de negocio de `docs/logicanegocio.md`:
  - `productos` como catálogo con `tipo_producto` (reventa/fabricado), `unidad_medida`, `stock_minimo`.
  - `inventario` como única fuente de verdad de `existencia_actual` y `costo_promedio_actual`.
  - `movimientos_inventario` (kardex) auditable con cantidad, costo unitario, existencia y costo resultantes.
  - `compras`, `producciones` y `producto_costos` separadas.
  - Triggers automáticos: compra/producción suman existencia y recalcular costo promedio ponderado (CPP); venta descuenta, congela `costo_unitario_momento_venta` y calcula `utilidad_calculada`.
- `incremental_ganancias.sql` (sin reset): agrega ganancia/margen a inventario y listado, y el RPC `obtener_resumen_ganancias`.
- `incremental_actualizar_producto.sql` (sin reset): agrega los RPC `actualizar_producto` y `ajustar_inventario`.

#### Ganancia visible en la app

- La columna `Ganancia` del inventario muestra la utilidad por unidad (precio de venta − costo promedio).
- La columna `Ganancia` del listado muestra la utilidad de cada venta.
- Consulta conversacional "¿cuánto gané este mes?" responde con ventas, costo de lo vendido, ganancia y margen.

#### Comandos nuevos de inventario

- `actualizar_producto`: "actualiza el precio de venta de gaseosas a 5", "configura stock mínimo de bananos en 10" (también precio de compra).
- `ajustar_inventario`: "corrige el inventario de gaseosas a 50".
- Fix: el título del inventario ahora muestra la cantidad real (`Inventario (2 productos)`), antes interpolaba mal la lista.

#### Validaciones

- `flutter analyze` sin errores.
- `flutter test`: 56 pruebas pasando.
- `flutter build apk --debug` correcto.
- Los RPCs nuevos fueron probados contra Supabase real con la key de la app (actualizar producto y ajustar inventario responden `true`).

## Estado técnico actual

- Rama de trabajo: `feature/fase-6-detalle-flujo-inventario`.
- Proveedor LLM por defecto: DeepSeek.
- Proveedor alternativo: OpenAI.
- Modelo OpenAI económico configurado: `gpt-4o-mini`.
- Base de datos principal: Supabase/Postgres.
- Build Android debug generado en `build/app/outputs/flutter-apk/app-debug.apk`.

## Variables de entorno relevantes

DeepSeek por defecto:

```env
LLM_API_KEY=tu_deepseek_api_key
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-chat
```

OpenAI como alternativa:

```env
LLM_PROVIDER=openai
OPENAI_API_KEY=tu_openai_api_key
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
```

El archivo `.env` local no debe subirse al repositorio.

## Validaciones recientes

- `flutter analyze`: sin errores.
- `flutter test`: 47 pruebas pasando.
- `flutter build apk --debug`: build generado correctamente.
- Prueba real con OpenAI:
  - Entrada: `compre 340 bananos a 10 quetzales cada uno`.
  - Resultado: transacción con `monto=3400`, `cantidad=340`, `precio_unitario=10`.
  - Descripción normalizada: `Compra de bananos`.

## Fase 7 iniciada

La siguiente fase es la **Fase 7: inventario**.

Objetivo: convertir las compras y ventas detectadas por IA en movimientos de inventario útiles para el microempresario.

Primer avance implementado:

- `productos` queda como catálogo de productos.
- `movimientos_inventario` registra entradas, salidas y ajustes.
- Los movimientos pueden quedar vinculados a una `transaccion_id`.
- `obtener_inventario` calcula existencias desde movimientos y conserva `productos.existencias` como stock inicial compatible con Fase 6.
- El LLM puede sugerir `producto_sugerido`, `accion_inventario` y `confianza_inventario` cuando una transacción tiene producto y cantidad clara.
- Al confirmar una transacción con producto/cantidad, la app registra el movimiento de inventario relacionado.
- El listado de inventario muestra estado: `OK`, `Bajo` o `Agotado`.

Segundo avance (lógica de negocio de docs/logicanegocio.md aplicada):

- La base de datos se reinició desde cero con `supabase/reset_desde_cero.sql` (borra todo y recrea el esquema + seeds base: 8 categorías, negocio/usuario/cuenta de prueba).
- Se separan los tres momentos del inventario: **compras** (entrada de lo comprado), **producciones** (entrada de lo fabricado con receta) y **ventas** (salida de lo que ya estaba en existencia).
- `producto_costos` es solo la receta para calcular `costo_total_lote` de una producción; ya no se usa para calcular utilidad por venta.
- Se usa **costo promedio ponderado (CPP)**: cada compra/producción recalcula el promedio; cada venta congela `costo_unitario_momento_venta` y calcula `utilidad_calculada` en la transacción.
- `inventario` es la única fuente de verdad de `existencia_actual` y `costo_promedio_actual`; `movimientos_inventario` (kardex) registra cada movimiento con existencia/costo resultante para auditar.
- Triggers automáticos: insert en `compras`/`producciones` actualiza el kardex; insert/update en `transacciones` tipo ingreso con `producto_id` descuenta inventario y calcula utilidad.
- La app ahora: al confirmar una compra con producto, crea el producto y registra la compra (entrada por trigger); al confirmar una venta, crea el producto y registra la transacción con `producto_id` (el trigger descuenta y congela costo).

Alcance propuesto:

- Modelo de productos o artículos.
- Existencias actuales por producto.
- Entradas de inventario cuando se registren compras de mercadería, materia prima o insumos.
- Salidas de inventario cuando se registren ventas de productos.
- Relación entre transacciones financieras y movimientos de inventario.
- Identificación asistida por IA del producto mencionado en frases informales.
- Corrección/confirmación de producto antes de afectar existencias.
- Consulta conversacional de stock, por ejemplo:
  - `¿cuántos bananos tengo?`
  - `muéstrame mi inventario`
  - `¿qué producto se está acabando?`
- Valor de inventario según costo unitario.
- Alertas simples de bajo inventario.

## Riesgos pendientes

- Validar que las categorías nivel 2 sean suficientemente específicas para separar mercadería, materia prima e insumos.
- Definir si un mismo producto puede tener distintos costos unitarios históricos.
- Definir cómo se manejarán productos ambiguos o escritos de muchas formas.
- Decidir si el inventario será exacto o aproximado para prototipo de tesis.
- Evitar que ventas sin producto claro descuenten inventario automáticamente.

## Decisión recomendada para Fase 7

Empezar con inventario simple y confirmable:

- Cada movimiento de inventario debe pasar por confirmación.
- No descontar stock si el producto no fue identificado con confianza suficiente.
- Usar el texto normalizado por IA para sugerir producto, pero permitir corrección manual.
- Mantener la transacción financiera como fuente principal y el movimiento de inventario como detalle relacionado.
