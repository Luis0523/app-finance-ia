# Fase 8: Gestión Integral de Inventario, Proveedores y Operaciones de Stock

Fecha de inicio: 2026-09-02  
Estado: En desarrollo  
Enfoque: 100% Visual, UI, Formularios y Experiencia Operativa para el Microempresario (sin alterar el modelo conversacional).

---

## 1. Justificación y Objetivos

La aplicación cuenta con un motor contable robusto (Kardex, Costo Promedio Ponderado, congelamiento de costos en ventas) y un flujo conversacional funcional. Sin embargo, para que un microempresario adopte la herramienta en su día a día comercial, necesita control directo, visual y ágil sobre sus productos y proveedores sin depender exclusivamente del chat.

### Objetivos Principales:
1. **Control total de catálogo:** Permitir editar cualquier dato de un producto existente (nombre, precios, unidad, categoría, stock mínimo) mediante su identificador único (`id`), resolviendo la limitación previa donde el nombre estaba bloqueado.
2. **Identidad visual:** Soporte de fotografía o imagen para productos, permitiendo una experiencia de catálogo visual atractiva y fácil de reconocer.
3. **Módulo formal de Proveedores:** Directorio de proveedores con datos de contacto comercial (teléfono, contacto, días de visita), acciones rápidas (llamada, WhatsApp) y vinculación con compras y productos.
4. **Ficha técnica y operaciones directas de almacén:** Pantalla de detalle de producto con mini-kardex y formularios rápidos para registrar compras directas o ajustes por merma/daño físico con motivo justificado.

---

## 2. Alcance por Módulos

### Módulo 1: Rediseño y Potenciación de la Pantalla de Inventario
- **Vistas alternables:**
  - **Modo Cuadrícula (Catálogo visual):** Tarjetas con foto del producto, existencias destacadas con badges de estado (OK, Stock Bajo, Agotado) y precio de venta.
  - **Modo Lista detallada:** Vista tabular compacta con existencias, costo promedio, precio de venta y utilidad.
- **Buscador y filtros en vivo:**
  - Búsqueda en tiempo real por nombre o código.
  - Filtros rápidos por estado: `Todos`, `⚠️ Stock Crítico`, `🚫 Agotados`.
  - Filtro por categoría del producto.
- **KPIs de inventario en cabecera:**
  - Total de productos activos.
  - Valor total del inventario en quetzales (capital inmovilizado en mercadería).
  - Alerta numérica de productos que requieren reposición inmediata.

### Módulo 2: Ficha Técnica, Edición Completa e Imágenes de Producto
- **Edición de producto por ID:**
  - Desacoplar la actualización del nombre: actualización directa vía RPC o repositorio usando el `id` (UUID).
  - Campo de nombre totalmente editable.
- **Soporte de imagen:**
  - Selección de imagen (cámara o galería) o URL directa.
  - Almacenamiento en Supabase Storage (bucket `productos`) o visualización de imagen con fallback visual elegante.
- **Atributos extendidos:**
  - `codigo_barras` / `sku`.
  - `categoria_producto` (Bebidas, Abarrotes, Limpieza, Lácteos, etc.).
  - `unidad_medida` seleccionable (Unidad, Libra, Docena, Caja, Litro, Quintal, etc.).
  - `stock_minimo` y `stock_maximo`.
  - `proveedor_id` habitual.
  - Calculadora en vivo de margen de ganancia y porcentaje en el formulario de creación/edición.
- **Ficha de Detalle de Producto:**
  - Visualización ampliada con foto, badges, barra de nivel de stock y datos del proveedor.
  - Mini-kardex con los últimos movimientos del producto.

### Módulo 3: Directorio y Gestión de Proveedores
- **Base de datos:**
  - Tabla `proveedores` (`id`, `negocio_id`, `nombre`, `contacto`, `telefono`, `direccion`, `dias_visita`, `notas`, `activo`).
  - Relación de `productos.proveedor_habitual_id` y `compras.proveedor_id`.
- **UI de Proveedores:**
  - Pestaña o pantalla de lista de proveedores.
  - Tarjetas con información clara y botones de acción rápida: llamada directa y enlace a WhatsApp.
  - Formulario de creación y edición de proveedores.
  - Historial de compras y productos surtidos por el proveedor.

### Módulo 4: Operaciones Rápidas de Stock (Sin necesidad de chat)
- **Registro de Compra / Entrada Directa:**
  - Formulario rápido: selección de producto, proveedor, cantidad, costo unitario y método de pago.
  - Impacto automático en tabla `compras`, actualización de kardex (`movimientos_inventario`) y recálculo de Costo Promedio Ponderado.
- **Ajuste de Inventario / Merma:**
  - Formulario de conteo físico y corrección de stock.
  - Selección de motivo de ajuste (`Conteo físico`, `Producto dañado / vencido`, `Autoconsumo / Merma`, `Corrección de error`).
  - Registro de auditoría en `movimientos_inventario` con tipo `ajuste`.

---

## 3. Plan de Implementación Técnica

1. **Base de Datos (SQL incremental sin reset):**
   - Script `supabase/incremental_fase8_inventario_proveedores.sql`.
   - Crear tabla `proveedores`.
   - Modificar tabla `productos` para agregar: `imagen_url`, `codigo_barras`, `categoria_producto`, `stock_maximo`, `proveedor_id`.
   - Crear/actualizar funciones RPC para actualizar producto por `id` y registrar compras/ajustes con motivo.
2. **Modelos y Repositorio Dart:**
   - Modelo `Proveedor` y actualización de `ProductoInventario` / `Producto`.
   - Métodos en `SupabaseRepository` para CRUD de proveedores, actualización de producto por ID, y carga de imágenes.
3. **Dependencias:**
   - Agregar `image_picker` y `url_launcher` en `pubspec.yaml` (o implementaciones desacopladas con fallback).
4. **Componentes Visuales y Pantallas:**
   - Actualizar `stock_screen.dart` con selector de vista (grid/list), buscador, filtros y KPIs.
   - Crear `producto_detalle_screen.dart` / modal de ficha de producto.
   - Mejorar `_ProductoForm` para soportar todos los campos (nombre editable, foto, proveedor, categorías).
   - Crear pantalla y componentes para `proveedores_screen.dart`.
   - Modal de operaciones rápidas (Entrada de compra / Merma).
5. **Verificación y Pruebas:**
   - Pruebas unitarias de modelos y repositorios.
   - `flutter analyze` y `flutter test`.
   - Build Android verificado.
