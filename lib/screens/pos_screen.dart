import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/producto_inventario.dart';
import '../providers/inventario_provider.dart';
import '../providers/pos_provider.dart';
import '../theme/lumina_theme.dart';
import '../widgets/imagen_producto.dart';
import '../widgets/pos_scanner_modal.dart';
import 'pos_carrito_sheet.dart';
import 'pos_cobro_modal.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _busqueda = '';
  String? _filtroCategoria;

  @override
  Widget build(BuildContext context) {
    final inventarioAsync = ref.watch(inventarioProvider);
    final carrito = ref.watch(posProvider);

    return Scaffold(
      backgroundColor: LuminaColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header con botón de Escáner y Buscador
            _buildHeader(context, inventarioAsync.valueOrNull ?? []),

            // Filtros de Categorías
            inventarioAsync.maybeWhen(
              data: (productos) => _buildCategoriasChips(productos),
              orElse: () => const SizedBox.shrink(),
            ),

            // Catálogo Táctil
            Expanded(
              child: inventarioAsync.when(
                data: (productos) {
                  final filtrados = _filtrarProductos(productos);

                  if (filtrados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: LuminaColors.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          const Text('No se encontraron productos'),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final prod = filtrados[index];
                      return _ProductoPosCard(
                        producto: prod,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(posProvider.notifier).agregarProducto(prod, 1);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Agregado: ${prod.nombre}'),
                              duration: const Duration(milliseconds: 900),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error al cargar productos: $e')),
              ),
            ),
          ],
        ),
      ),
      // Barra flotante inferior de Ticket / Cobro
      bottomSheet: !carrito.estaVacio
          ? _BarraFlotanteCarrito(
              totalArticulos: carrito.totalArticulos,
              totalVenta: carrito.totalVenta,
              onVerCarrito: () => PosCarritoSheet.abrir(context),
              onCobrar: () => PosCobroModal.cobrar(
                context,
                items: carrito.items,
                total: carrito.totalVenta,
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, List<ProductoInventario> productos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale, color: LuminaColors.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Caja / Punto de Venta',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
              ),
              // Botón destacado de Escaneo Continuo
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LuminaColors.primary,
                  foregroundColor: LuminaColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => PosScannerModal.abrir(context, catalogo: productos),
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Escanear'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Buscador rápido
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o código de barras...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _busqueda = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriasChips(List<ProductoInventario> productos) {
    final categorias = productos
        .map((p) => p.categoriaProducto)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (categorias.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: const Text('Todos'),
            selected: _filtroCategoria == null,
            onSelected: (_) => setState(() => _filtroCategoria = null),
          ),
          const SizedBox(width: 8),
          ...categorias.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: _filtroCategoria == cat,
                onSelected: (sel) => setState(() => _filtroCategoria = sel ? cat : null),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<ProductoInventario> _filtrarProductos(List<ProductoInventario> productos) {
    return productos.where((p) {
      if (_filtroCategoria != null && p.categoriaProducto != _filtroCategoria) {
        return false;
      }
      if (_busqueda.isNotEmpty) {
        final matchNombre = p.nombre.toLowerCase().contains(_busqueda);
        final matchCodigo =
            p.codigoBarras != null && p.codigoBarras!.toLowerCase().contains(_busqueda);
        if (!matchNombre && !matchCodigo) return false;
      }
      return true;
    }).toList();
  }
}

class _ProductoPosCard extends StatelessWidget {
  const _ProductoPosCard({
    required this.producto,
    required this.onTap,
  });

  final ProductoInventario producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final sinStock = p.existencias <= 0;

    return Material(
      color: LuminaColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(LuminaRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: LuminaColors.cardBorder),
            borderRadius: BorderRadius.circular(LuminaRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: LuminaColors.surfaceContainerHigh,
                      child: ImagenProducto(
                        url: p.imagenUrl,
                        iconSize: 36,
                      ),
                    ),
                    if (sinStock)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: LuminaColors.negative,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Agotado',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Datos del producto
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Q${p.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: LuminaColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: LuminaColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: LuminaColors.primary,
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
      ),
    );
  }
}

class _BarraFlotanteCarrito extends StatelessWidget {
  const _BarraFlotanteCarrito({
    required this.totalArticulos,
    required this.totalVenta,
    required this.onVerCarrito,
    required this.onCobrar,
  });

  final int totalArticulos;
  final double totalVenta;
  final VoidCallback onVerCarrito;
  final VoidCallback onCobrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainerHigh,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
        border: const Border(
          top: BorderSide(color: LuminaColors.cardBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            InkWell(
              onTap: onVerCarrito,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Badge.count(
                      count: totalArticulos,
                      backgroundColor: LuminaColors.primary,
                      child: const Icon(Icons.shopping_cart, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TICKET',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Q${totalVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: LuminaColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: LuminaColors.primary,
                foregroundColor: LuminaColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onCobrar,
              icon: const Icon(Icons.point_of_sale, size: 18),
              label: const Text(
                'Cobrar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
