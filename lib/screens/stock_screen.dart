import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/producto_inventario.dart';
import '../providers/inventario_provider.dart';
import '../providers/proveedores_provider.dart';
import '../providers/supabase_provider.dart';
import '../services/supabase_repository.dart';
import '../theme/lumina_theme.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../widgets/imagen_producto.dart';
import 'operacion_stock_modal.dart';
import 'producto_detalle_modal.dart';
import 'proveedores_screen.dart';

enum ModoVistaInventario { cuadricula, lista }

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  ModoVistaInventario _modoVista = ModoVistaInventario.cuadricula;
  String _busqueda = '';
  String _filtroEstado = 'todos'; // todos, bajo, agotado
  String? _filtroCategoria;

  @override
  Widget build(BuildContext context) {
    final inventarioAsync = ref.watch(inventarioProvider);

    return Scaffold(
      backgroundColor: LuminaColors.surface,
      floatingActionButton: inventarioAsync.maybeWhen(
        data: (productos) => _BotonOperacionesFlotante(
          onRegistrarCompra: () => _abrirOperacionStock(
            tipo: TipoOperacionStock.compra,
            productos: productos,
          ),
          onAjustarMerma: () => _abrirOperacionStock(
            tipo: TipoOperacionStock.ajuste,
            productos: productos,
          ),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              modoVista: _modoVista,
              onCambiarModoVista: (modo) => setState(() => _modoVista = modo),
              onRecargar: () => ref.invalidate(inventarioProvider),
              onAgregar: () => _abrirFormulario(producto: null),
              onAbrirProveedores: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProveedoresScreen()),
                );
              },
            ),
            Expanded(
              child: inventarioAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(inventarioProvider),
                ),
                data: (productos) {
                  // Filtrar lista
                  final filtrados = productos.where((p) {
                    if (_busqueda.isNotEmpty) {
                      final q = _busqueda.toLowerCase();
                      final matchNombre = p.nombre.toLowerCase().contains(q);
                      final matchCodigo = p.codigoBarras?.toLowerCase().contains(q) ?? false;
                      final matchCat = p.categoriaProducto?.toLowerCase().contains(q) ?? false;
                      if (!matchNombre && !matchCodigo && !matchCat) return false;
                    }

                    if (_filtroEstado == 'bajo' && p.estado != 'bajo') return false;
                    if (_filtroEstado == 'agotado' && p.estado != 'agotado') return false;

                    if (_filtroCategoria != null && p.categoriaProducto != _filtroCategoria) {
                      return false;
                    }

                    return true;
                  }).toList();

                  // Categorías disponibles para chips
                  final categorias = productos
                      .map((p) => p.categoriaProducto)
                      .whereType<String>()
                      .where((c) => c.trim().isNotEmpty)
                      .toSet()
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(inventarioProvider.future),
                    color: LuminaColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        // KPIs del Inventario
                        _ResumenKpis(productos: productos),
                        const SizedBox(height: 12),

                        // Barra de Búsqueda
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, código o categoría...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _busqueda.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _busqueda = ''),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (val) => setState(() => _busqueda = val.trim()),
                        ),
                        const SizedBox(height: 10),

                        // Chips de Filtro
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FiltroChip(
                                label: 'Todos (${productos.length})',
                                seleccionado: _filtroEstado == 'todos' && _filtroCategoria == null,
                                onTap: () => setState(() {
                                  _filtroEstado = 'todos';
                                  _filtroCategoria = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              _FiltroChip(
                                label: '⚠️ Stock Bajo',
                                color: Colors.amber.shade800,
                                seleccionado: _filtroEstado == 'bajo',
                                onTap: () => setState(() {
                                  _filtroEstado = _filtroEstado == 'bajo' ? 'todos' : 'bajo';
                                }),
                              ),
                              const SizedBox(width: 8),
                              _FiltroChip(
                                label: '🚫 Agotados',
                                color: LuminaColors.negative,
                                seleccionado: _filtroEstado == 'agotado',
                                onTap: () => setState(() {
                                  _filtroEstado =
                                      _filtroEstado == 'agotado' ? 'todos' : 'agotado';
                                }),
                              ),
                              for (final cat in categorias) ...[
                                const SizedBox(width: 8),
                                _FiltroChip(
                                  label: cat,
                                  seleccionado: _filtroCategoria == cat,
                                  onTap: () => setState(() {
                                    _filtroCategoria = _filtroCategoria == cat ? null : cat;
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Vista de Productos
                        if (filtrados.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.search_off_outlined,
                                    size: 48,
                                    color: LuminaColors.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    productos.isEmpty
                                        ? 'No tienes productos en inventario'
                                        : 'No hay productos con los filtros seleccionados',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: LuminaColors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_modoVista == ModoVistaInventario.cuadricula)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: filtrados.length,
                            itemBuilder: (context, index) {
                              final p = filtrados[index];
                              return _ProductoCuadriculaCard(
                                producto: p,
                                onTap: () => _abrirDetalleProducto(p, productos),
                              );
                            },
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtrados.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final p = filtrados[index];
                              return _ProductoListaCard(
                                producto: p,
                                onTap: () => _abrirDetalleProducto(p, productos),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDetalleProducto(
    ProductoInventario producto,
    List<ProductoInventario> productos,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductoDetalleModal(
        producto: producto,
        onEditar: () {
          Navigator.of(context).pop();
          _abrirFormulario(producto: producto);
        },
        onRegistrarCompra: () {
          Navigator.of(context).pop();
          _abrirOperacionStock(
            tipo: TipoOperacionStock.compra,
            productos: productos,
            seleccionado: producto,
          );
        },
        onAjustarStock: () {
          Navigator.of(context).pop();
          _abrirOperacionStock(
            tipo: TipoOperacionStock.ajuste,
            productos: productos,
            seleccionado: producto,
          );
        },
      ),
    );
  }

  Future<void> _abrirOperacionStock({
    required TipoOperacionStock tipo,
    required List<ProductoInventario> productos,
    ProductoInventario? seleccionado,
  }) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LuminaColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
      ),
      builder: (_) => OperacionStockModal(
        tipo: tipo,
        productos: productos,
        productoSeleccionado: seleccionado,
      ),
    );

    if (guardado == true) {
      ref.invalidate(inventarioProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tipo == TipoOperacionStock.compra
                ? 'Compra registrada y stock actualizado en Kardex.'
                : 'Ajuste de inventario aplicado exitosamente.',
          ),
        ),
      );
    }
  }

  Future<void> _abrirFormulario({
    required ProductoInventario? producto,
  }) async {
    final repo = ref.read(supabaseRepositoryProvider);
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LuminaColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
      ),
      builder: (_) => _ProductoForm(repo: repo, producto: producto),
    );

    if (guardado == true) {
      ref.invalidate(inventarioProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            producto == null
                ? 'Producto agregado exitosamente al inventario.'
                : 'Producto actualizado exitosamente.',
          ),
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.modoVista,
    required this.onCambiarModoVista,
    required this.onRecargar,
    required this.onAgregar,
    required this.onAbrirProveedores,
  });

  final ModoVistaInventario modoVista;
  final ValueChanged<ModoVistaInventario> onCambiarModoVista;
  final VoidCallback onRecargar;
  final VoidCallback onAgregar;
  final VoidCallback onAbrirProveedores;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  'Catálogo, existencias y costos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LuminaColors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Proveedores',
            icon: const Icon(Icons.local_shipping_outlined),
            color: LuminaColors.primary,
            onPressed: onAbrirProveedores,
          ),
          IconButton(
            tooltip: modoVista == ModoVistaInventario.cuadricula
                ? 'Ver en lista'
                : 'Ver en cuadrícula',
            icon: Icon(
              modoVista == ModoVistaInventario.cuadricula
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
            ),
            color: LuminaColors.onSurfaceVariant,
            onPressed: () {
              onCambiarModoVista(
                modoVista == ModoVistaInventario.cuadricula
                    ? ModoVistaInventario.lista
                    : ModoVistaInventario.cuadricula,
              );
            },
          ),
          IconButton(
            onPressed: onRecargar,
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            color: LuminaColors.onSurfaceVariant,
          ),
          TextButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo'),
          ),
        ],
      ),
    );
  }
}

class _ResumenKpis extends StatelessWidget {
  const _ResumenKpis({required this.productos});

  final List<ProductoInventario> productos;

  @override
  Widget build(BuildContext context) {
    final valorTotal = productos.fold<double>(0, (acc, p) => acc + p.valorTotal);
    final bajos = productos.where((p) => p.estado == 'bajo' || p.estado == 'agotado').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LuminaColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capital en mercadería',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: LuminaColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Q${valorTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: LuminaColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: LuminaColors.outlineVariant,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productos',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: LuminaColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${productos.length} activos',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 12),
          if (bajos > 0) ...[
            Container(
              height: 36,
              width: 1,
              color: LuminaColors.outlineVariant,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Por reponer',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber.shade800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$bajos críticos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool seleccionado;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? LuminaColors.primary;

    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: seleccionado ? LuminaColors.onPrimary : chipColor,
        fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      selectedColor: chipColor,
      backgroundColor: chipColor.withValues(alpha: 0.08),
      side: BorderSide(
        color: seleccionado ? chipColor : chipColor.withValues(alpha: 0.25),
      ),
      showCheckmark: false,
    );
  }
}

class _ProductoCuadriculaCard extends StatelessWidget {
  const _ProductoCuadriculaCard({required this.producto, required this.onTap});

  final ProductoInventario producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = producto;
    final agotado = p.estado == 'agotado';
    final bajo = p.estado == 'bajo';

    final badgeColor = agotado
        ? LuminaColors.negative
        : bajo
            ? Colors.amber.shade800
            : LuminaColors.positive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuminaRadii.card),
      child: Container(
        decoration: BoxDecoration(
          color: LuminaColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(LuminaRadii.card),
          border: Border.all(color: LuminaColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: LuminaColors.primary.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto con Badge de estado
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(LuminaRadii.card),
                  ),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: LuminaColors.surfaceContainerHigh,
                    child: ImagenProducto(
                      url: p.imagenUrl,
                      height: 100,
                      width: double.infinity,
                      iconSize: 40,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (p.estado ?? 'OK').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.categoriaProducto ?? p.unidadMedida,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LuminaColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Q${p.precioVenta.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: LuminaColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${p.existencias.toStringAsFixed(0)} ${p.unidadMedida}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: (agotado || bajo) ? badgeColor : LuminaColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductoListaCard extends StatelessWidget {
  const _ProductoListaCard({required this.producto, required this.onTap});

  final ProductoInventario producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = producto;
    final agotado = p.estado == 'agotado';
    final bajo = p.estado == 'bajo';

    final badgeColor = agotado
        ? LuminaColors.negative
        : bajo
            ? Colors.amber.shade800
            : LuminaColors.positive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuminaRadii.card),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LuminaColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(LuminaRadii.card),
          border: Border.all(color: LuminaColors.cardBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                color: LuminaColors.surfaceContainerHigh,
                child: ImagenProducto(
                  url: p.imagenUrl,
                  width: 48,
                  height: 48,
                  iconSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${p.categoriaProducto != null ? '${p.categoriaProducto!} • ' : ''}Q${p.precioVenta.toStringAsFixed(2)} c/u',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LuminaColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${p.existencias.toStringAsFixed(0)} ${p.unidadMedida}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (agotado || bajo) ? badgeColor : LuminaColors.onSurface,
                  ),
                ),
                Text(
                  'Q${p.valorTotal.toStringAsFixed(2)} total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: LuminaColors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: LuminaColors.outline),
          ],
        ),
      ),
    );
  }
}

class _BotonOperacionesFlotante extends StatelessWidget {
  const _BotonOperacionesFlotante({
    required this.onRegistrarCompra,
    required this.onAjustarMerma,
  });

  final VoidCallback onRegistrarCompra;
  final VoidCallback onAjustarMerma;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab_compra',
          onPressed: onRegistrarCompra,
          backgroundColor: LuminaColors.primary,
          foregroundColor: LuminaColors.onPrimary,
          icon: const Icon(Icons.add_shopping_cart, size: 18),
          label: const Text('Comprar'),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: 'fab_merma',
          tooltip: 'Ajuste / Merma',
          onPressed: onAjustarMerma,
          backgroundColor: LuminaColors.surfaceContainerLowest,
          foregroundColor: Colors.amber.shade900,
          child: const Icon(Icons.tune, size: 18),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: LuminaColors.outline),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el inventario.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// FORMULARIO RENOVADO: NOMBRE TOTALMENTE EDITABLE, FOTO, PROVEEDORES Y CALCULADORA EN VIVO
class _ProductoForm extends ConsumerStatefulWidget {
  const _ProductoForm({required this.repo, this.producto});

  final FinanzasRepository repo;
  final ProductoInventario? producto;

  @override
  ConsumerState<_ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends ConsumerState<_ProductoForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _precioCompra;
  late final TextEditingController _precioVenta;
  late final TextEditingController _existencias;
  late final TextEditingController _stockMinimo;
  late final TextEditingController _stockMaximo;
  late final TextEditingController _codigoBarras;
  late final TextEditingController _imagenUrl;

  String _unidadMedida = 'unidad';
  String? _categoriaProducto;
  String? _proveedorId;

  bool _guardando = false;
  String? _error;

  final List<String> _unidades = [
    'unidad',
    'libra',
    'docena',
    'caja',
    'litro',
    'quintal',
    'paquete',
    'bolsa',
  ];

  final List<String> _categoriasSugeridas = [
    'Abarrotes',
    'Bebidas',
    'Lácteos',
    'Granos y Harinas',
    'Carnes y Embutidos',
    'Frutas y Verduras',
    'Limpieza y Hogar',
    'Snacks y Golosinas',
    'Otros',
  ];

  bool _subiendoImagen = false;

  bool get _esNuevo => widget.producto == null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;

    // ¡El nombre ahora se inicializa libremente para edición!
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _precioCompra = TextEditingController(
      text: p != null ? p.precioCompra.toStringAsFixed(2) : '',
    );
    _precioVenta = TextEditingController(
      text: p != null ? p.precioVenta.toStringAsFixed(2) : '',
    );
    _existencias = TextEditingController(
      text: p != null ? p.existencias.toStringAsFixed(0) : '',
    );
    _stockMinimo = TextEditingController(
      text: p?.stockMinimo != null ? p!.stockMinimo!.toStringAsFixed(0) : '',
    );
    _stockMaximo = TextEditingController(
      text: p?.stockMaximo != null ? p!.stockMaximo!.toStringAsFixed(0) : '',
    );
    _codigoBarras = TextEditingController(text: p?.codigoBarras ?? '');
    _imagenUrl = TextEditingController(text: p?.imagenUrl ?? '');

    _unidadMedida = p?.unidadMedida ?? 'unidad';
    _categoriaProducto = p?.categoriaProducto;
    _proveedorId = p?.proveedorId;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precioCompra.dispose();
    _precioVenta.dispose();
    _existencias.dispose();
    _stockMinimo.dispose();
    _stockMaximo.dispose();
    _codigoBarras.dispose();
    _imagenUrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
      if (xfile == null) return;

      setState(() => _subiendoImagen = true);
      final bytes = await xfile.readAsBytes();

      // Intentar subir a Supabase Storage
      final urlRemota = await widget.repo.subirImagenProducto(
        bytes: bytes,
        extension: 'jpg',
      );

      if (urlRemota != null) {
        if (mounted) {
          setState(() {
            _imagenUrl.text = urlRemota;
            _subiendoImagen = false;
          });
        }
      } else {
        // Fallback a data URI base64 para que la foto funcione siempre
        final b64 = base64Encode(bytes);
        if (mounted) {
          setState(() {
            _imagenUrl.text = 'data:image/jpeg;base64,$b64';
            _subiendoImagen = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _subiendoImagen = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la imagen: $e')),
        );
      }
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LuminaColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Foto del Producto (opcional)',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: LuminaColors.primary),
                title: const Text('Tomar foto con la cámara'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: LuminaColors.primary),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: LuminaColors.primary),
                title: const Text('Escribir o pegar enlace web'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _mostrarDialogoUrl();
                },
              ),
              if (_imagenUrl.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: LuminaColors.negative),
                  title: const Text(
                    'Eliminar foto',
                    style: TextStyle(color: LuminaColors.negative),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _imagenUrl.clear());
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoUrl() {
    final controller = TextEditingController(
      text: _imagenUrl.text.startsWith('data:') ? '' : _imagenUrl.text,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enlace de imagen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://ejemplo.com/foto.jpg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _imagenUrl.text = controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _escanearCodigoBarras() async {
    final codigo = await BarcodeScannerModal.escanear(context);
    if (codigo != null && mounted) {
      setState(() => _codigoBarras.text = codigo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código escaneado: $codigo')),
      );
    }
  }

  double? _parsar(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final nombre = _nombre.text.trim();
      final precioCompra = _parsar(_precioCompra.text);
      final precioVenta = _parsar(_precioVenta.text);
      final existencias = _parsar(_existencias.text);
      final stockMinimo = _parsar(_stockMinimo.text);
      final stockMaximo = _parsar(_stockMaximo.text);
      final codigoBarras = _codigoBarras.text.trim().isEmpty ? null : _codigoBarras.text.trim();
      final imagenUrl = _imagenUrl.text.trim().isEmpty ? null : _imagenUrl.text.trim();

      if (_esNuevo) {
        final id = await widget.repo.buscarOCrearProducto(
          nombre: nombre,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          unidadMedida: _unidadMedida,
        );

        if (id == null) {
          setState(() {
            _error = 'No se pudo crear el producto.';
            _guardando = false;
          });
          return;
        }

        // Actualizar campos extendidos
        await widget.repo.actualizarProductoPorId(
          productoId: id,
          nuevoNombre: nombre,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          stockMinimo: stockMinimo,
          stockMaximo: stockMaximo,
          unidadMedida: _unidadMedida,
          categoriaProducto: _categoriaProducto,
          codigoBarras: codigoBarras,
          imagenUrl: imagenUrl,
          proveedorId: _proveedorId,
        );

        if (existencias != null && existencias > 0) {
          await widget.repo.ajustarInventario(
            nombre: nombre,
            cantidadObjetivo: existencias,
          );
        }
      } else {
        // EDICIÓN DE PRODUCTO EXISTENTE: ¡Usa el ID único y permite renombrar!
        bool ok = false;
        final prodId = widget.producto!.id;

        if (prodId != null) {
          ok = await widget.repo.actualizarProductoPorId(
            productoId: prodId,
            nuevoNombre: nombre,
            precioCompra: precioCompra,
            precioVenta: precioVenta,
            stockMinimo: stockMinimo,
            stockMaximo: stockMaximo,
            unidadMedida: _unidadMedida,
            categoriaProducto: _categoriaProducto,
            codigoBarras: codigoBarras,
            imagenUrl: imagenUrl,
            proveedorId: _proveedorId,
          );
        } else {
          // Fallback al nombre anterior si no hubiera ID
          ok = await widget.repo.actualizarProducto(
            nombre: widget.producto!.nombre,
            precioCompra: precioCompra,
            precioVenta: precioVenta,
            stockMinimo: stockMinimo,
          );
        }

        if (!ok) {
          setState(() {
            _error = 'No se pudo actualizar el producto.';
            _guardando = false;
          });
          return;
        }

        if (existencias != null) {
          if (prodId != null) {
            await widget.repo.ajustarInventarioConMotivo(
              productoId: prodId,
              cantidadObjetivo: existencias,
              motivo: 'Ajuste desde edición de producto',
            );
          } else {
            await widget.repo.ajustarInventario(
              nombre: nombre,
              cantidadObjetivo: existencias,
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Ocurrió un error al guardar: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esNuevo = _esNuevo;
    final proveedoresAsync = ref.watch(proveedoresProvider);

    // Cálculo en tiempo real de márgenes
    final costo = double.tryParse(_precioCompra.text.trim()) ?? 0;
    final venta = double.tryParse(_precioVenta.text.trim()) ?? 0;
    final ganancia = venta - costo;
    final margen = venta > 0 ? (ganancia / venta) * 100 : 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      esNuevo ? 'Agregar Producto' : 'Editar Producto',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                esNuevo
                    ? 'Completa los datos del producto para tu catálogo.'
                    : 'Modifica cualquier dato de este producto (incluyendo su nombre).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: LuminaColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: LuminaColors.negative)),
                const SizedBox(height: 12),
              ],

              // 1. NOMBRE DEL PRODUCTO (¡Siempre editable!)
              TextFormField(
                controller: _nombre,
                enabled: true, // ¡Siempre habilitado!
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto *',
                  hintText: 'Ej. Gaseosa Coca Cola 600ml, Banano Criollo',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa el nombre del producto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 2. FOTO DEL PRODUCTO (Cámara / Galería / Enlace)
              InkWell(
                onTap: _subiendoImagen ? null : _mostrarOpcionesImagen,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 125,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: LuminaColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _imagenUrl.text.isNotEmpty
                          ? LuminaColors.primary
                          : LuminaColors.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: _subiendoImagen
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(height: 8),
                              Text('Procesando foto...'),
                            ],
                          ),
                        )
                      : _imagenUrl.text.isNotEmpty
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Center(
                                    child: ImagenProducto(
                                      url: _imagenUrl.text,
                                      height: 125,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Cambiar foto',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 34,
                                  color: LuminaColors.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Subir foto del producto (opcional)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: LuminaColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toca para tomar foto con la cámara o elegir de galería',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: LuminaColors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. CATEGORÍA Y UNIDAD DE MEDIDA
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoriaProducto,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('General')),
                        ..._categoriasSugeridas.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (c) => setState(() => _categoriaProducto = c),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidadMedida,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: _unidades.map((u) {
                        return DropdownMenuItem(value: u, child: Text(u.toUpperCase()));
                      }).toList(),
                      onChanged: (u) => setState(() => _unidadMedida = u ?? 'unidad'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. PRECIOS Y CALCULADORA DE MARGEN EN TIEMPO REAL
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _precioCompra,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Costo Compra',
                        prefixText: 'Q ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _precioVenta,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Precio Venta',
                        prefixText: 'Q ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (costo > 0 || venta > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ganancia >= 0
                        ? LuminaColors.positive.withValues(alpha: 0.1)
                        : LuminaColors.negative.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ganancia estimada: Q${ganancia.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ganancia >= 0 ? LuminaColors.positive : LuminaColors.negative,
                        ),
                      ),
                      Text(
                        'Margen: ${margen.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ganancia >= 0 ? LuminaColors.positive : LuminaColors.negative,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // 5. EXISTENCIAS Y STOCK MÍNIMO
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _existencias,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Existencias actuales',
                        suffixText: _unidadMedida,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockMinimo,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Alerta Stock Mínimo',
                        hintText: 'Ej. 5',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 6. PROVEEDOR HABITUAL
              proveedoresAsync.maybeWhen(
                data: (proveedores) {
                  return DropdownButtonFormField<String>(
                    initialValue: _proveedorId,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor habitual (opcional)',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin proveedor asignado')),
                      ...proveedores.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre))),
                    ],
                    onChanged: (id) => setState(() => _proveedorId = id),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // 7. CÓDIGO DE BARRAS / SKU
              TextFormField(
                controller: _codigoBarras,
                decoration: InputDecoration(
                  labelText: 'Código de barras / SKU (opcional)',
                  hintText: 'Ej. 740100523456 o toca el escáner',
                  prefixIcon: const Icon(Icons.qr_code_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: LuminaColors.primary,
                    ),
                    tooltip: 'Escanear con cámara',
                    onPressed: _escanearCodigoBarras,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LuminaColors.onPrimary,
                          ),
                        )
                      : Text(esNuevo ? 'Agregar Producto' : 'Guardar Cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
