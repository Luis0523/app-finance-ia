import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/movimiento_kardex.dart';
import '../models/producto_inventario.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';
import '../widgets/imagen_producto.dart';

class ProductoDetalleModal extends ConsumerStatefulWidget {
  const ProductoDetalleModal({
    super.key,
    required this.producto,
    required this.onEditar,
    required this.onAjustarStock,
    required this.onRegistrarCompra,
  });

  final ProductoInventario producto;
  final VoidCallback onEditar;
  final VoidCallback onAjustarStock;
  final VoidCallback onRegistrarCompra;

  @override
  ConsumerState<ProductoDetalleModal> createState() => _ProductoDetalleModalState();
}

class _ProductoDetalleModalState extends ConsumerState<ProductoDetalleModal> {
  List<MovimientoKardex>? _kardex;
  bool _cargandoKardex = true;

  @override
  void initState() {
    super.initState();
    _cargarKardex();
  }

  Future<void> _cargarKardex() async {
    final id = widget.producto.id;
    if (id == null) {
      setState(() => _cargandoKardex = false);
      return;
    }

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final movs = await repo.obtenerKardexProducto(productoId: id, limite: 20);
      if (mounted) {
        setState(() {
          _kardex = movs;
          _cargandoKardex = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoKardex = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: 'Q', decimalDigits: 2);

    final estadoColor = p.estado == 'agotado'
        ? LuminaColors.negative
        : p.estado == 'bajo'
            ? Colors.amber.shade800
            : LuminaColors.positive;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: LuminaColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(LuminaRadii.card),
            ),
          ),
          child: Column(
            children: [
              // Manija superior
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LuminaColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Cabecera: Imagen o Avatar grande + Título
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: LuminaColors.surfaceContainerHigh,
                            child: ImagenProducto(
                              url: p.imagenUrl,
                              width: 80,
                              height: 80,
                              iconSize: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (p.categoriaProducto != null &&
                                      p.categoriaProducto!.isNotEmpty)
                                    _TagBadge(
                                      label: p.categoriaProducto!,
                                      color: LuminaColors.primary,
                                    ),
                                  _TagBadge(
                                    label: p.unidadMedida,
                                    color: LuminaColors.onSurfaceVariant,
                                  ),
                                  if (p.codigoBarras != null &&
                                      p.codigoBarras!.isNotEmpty)
                                    _TagBadge(
                                      label: 'SKU: ${p.codigoBarras}',
                                      color: LuminaColors.outline,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar producto',
                          onPressed: widget.onEditar,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tarjeta de Precios y Rentabilidad
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LuminaColors.surface,
                        borderRadius: BorderRadius.circular(LuminaRadii.card),
                        border: Border.all(color: LuminaColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Precios y Rentabilidad',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: LuminaColors.primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: LuminaColors.positive.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Margen: ${p.margenPorcentual.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: LuminaColors.positive,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _DatoFinanciero(
                                label: 'Precio Venta',
                                valor: currency.format(p.precioVenta),
                                color: LuminaColors.onSurface,
                              ),
                              _DatoFinanciero(
                                label: 'Costo Promedio',
                                valor: currency.format(p.costoPromedio ?? p.precioCompra),
                                color: LuminaColors.onSurfaceVariant,
                              ),
                              _DatoFinanciero(
                                label: 'Ganancia / ud',
                                valor: currency.format(p.utilidadUnitaria ?? (p.precioVenta - (p.costoPromedio ?? p.precioCompra))),
                                color: LuminaColors.positive,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tarjeta de Existencias y Estado
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LuminaColors.surface,
                        borderRadius: BorderRadius.circular(LuminaRadii.card),
                        border: Border.all(color: LuminaColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Control de Existencias',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: LuminaColors.primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: estadoColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (p.estado ?? 'OK').toUpperCase(),
                                  style: TextStyle(
                                    color: estadoColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.existencias.toStringAsFixed(0)} ${p.unidadMedida}',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: estadoColor,
                                      ),
                                    ),
                                    Text(
                                      'Valor total: ${currency.format(p.valorTotal)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: LuminaColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.stockMinimo != null)
                                Text(
                                  'Mínimo: ${p.stockMinimo!.toStringAsFixed(0)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: LuminaColors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (p.proveedorNombre != null && p.proveedorNombre!.isNotEmpty) ...[
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 16, color: LuminaColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Proveedor habitual: ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: LuminaColors.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  p.proveedorNombre!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botones de Acción Rápida de Inventario
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.onRegistrarCompra,
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Registrar Compra'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onAjustarStock,
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('Ajustar / Merma'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Sección Mini-Kardex
                    Text(
                      'Historial de Movimientos (Kardex)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_cargandoKardex)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_kardex == null || _kardex!.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: LuminaColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No hay movimientos registrados para este producto.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: LuminaColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ..._kardex!.map((m) {
                        final esEntrada = m.cantidad > 0;
                        final color = esEntrada ? LuminaColors.positive : LuminaColors.negative;
                        final fechaFmt = DateFormat('dd/MM/yyyy').format(m.fecha);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LuminaColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: LuminaColors.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                esEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                                color: color,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          m.tipoMovimiento.toUpperCase(),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          fechaFmt,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: LuminaColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (m.motivo != null && m.motivo!.isNotEmpty)
                                      Text(
                                        m.motivo!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: LuminaColors.onSurfaceVariant,
                                        ),
                                      ),
                                    Text(
                                      'Stock resultante: ${m.existenciaResultante.toStringAsFixed(0)} @ ${currency.format(m.costoPromedioResultante)}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: LuminaColors.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${esEntrada ? '+' : ''}${m.cantidad.toStringAsFixed(0)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DatoFinanciero extends StatelessWidget {
  const _DatoFinanciero({
    required this.label,
    required this.valor,
    required this.color,
  });

  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: LuminaColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
