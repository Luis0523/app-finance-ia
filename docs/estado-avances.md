# Estado y Avances del Proyecto

Fecha de actualización: 2026-08-22

## Resumen ejecutivo

La app ya cuenta con el flujo principal del prototipo: voz o texto, clasificación con IA, confirmación de la transacción, persistencia en Supabase y consultas conversacionales sobre movimientos registrados. La fase actual está cerrando la parte de transacciones detalladas y reportes básicos antes de pasar a inventario.

## Fase actual

Estamos en la **Fase 6b: detalle de transacciones, listados y configuración de LLM**.

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

## Siguiente fase

La siguiente fase debe ser la **Fase 7: inventario**.

Objetivo: convertir las compras y ventas detectadas por IA en movimientos de inventario útiles para el microempresario.

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
