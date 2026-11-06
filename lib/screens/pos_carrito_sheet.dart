import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/producto_inventario.dart';
import '../providers/pos_provider.dart';
import '../theme/lumina_theme.dart';
import '../widgets/imagen_producto.dart';
import 'pos_cobro_modal.dart';

class PosCarritoSheet extends ConsumerWidget {
  const PosCarritoSheet({super.key});

  static Future<void> abrir(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PosCarritoSheet(),
    );
  }

  String _getKey(ProductoInventario p) {
    if (p.id != null && p.id!.isNotEmpty) return p.id!;
    return p.nombre.toLowerCase().trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(posProvider);
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: LuminaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
      ),
      child: Column(
        children: [
          // Barra de título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: LuminaColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ticket de Venta (${carrito.totalArticulos} artículos)',
                    style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18),
                  ),
                ),
                if (!carrito.estaVacio)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: LuminaColors.negative),
                    onPressed: () {
                      ref.read(posProvider.notifier).limpiarCarrito();
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Vaciar'),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          // Lista de Productos en el Carrito
          Expanded(
            child: carrito.estaVacio
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove_shopping_cart_outlined,
                          size: 60,
                          color: LuminaColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'El ticket está vacío',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: LuminaColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escanea un código o toca productos del catálogo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: LuminaColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: carrito.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = carrito.items[index];
                      final key = _getKey(item.producto);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: LuminaColors.surfaceContainerHigh,
                                child: ImagenProducto(
                                  url: item.producto.imagenUrl,
                                  width: 44,
                                  height: 44,
                                  iconSize: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.producto.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Q${item.precioUnitario.toStringAsFixed(2)} c/u',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: LuminaColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stepper de Cantidad
                            Container(
                              decoration: BoxDecoration(
                                color: LuminaColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed: () {
                                      ref
                                          .read(posProvider.notifier)
                                          .decrementarCantidad(key);
                                    },
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text(
                                    item.cantidad % 1 == 0
                                        ? item.cantidad.toInt().toString()
                                        : item.cantidad.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed: () {
                                      ref
                                          .read(posProvider.notifier)
                                          .incrementarCantidad(key);
                                    },
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 65,
                              child: Text(
                                'Q${item.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Pie de cobro
          if (!carrito.estaVacio)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: LuminaColors.surface,
                border: const Border(
                  top: BorderSide(color: LuminaColors.cardBorder),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a Cobrar:'),
                        Text(
                          'Q${carrito.totalVenta.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: LuminaColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: LuminaColors.primary,
                          foregroundColor: LuminaColors.onPrimary,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await PosCobroModal.cobrar(
                            context,
                            items: carrito.items,
                            total: carrito.totalVenta,
                          );
                        },
                        icon: const Icon(Icons.point_of_sale),
                        label: Text(
                          'Cobrar Q${carrito.totalVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
