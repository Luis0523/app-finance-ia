import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/producto_inventario.dart';
import '../models/proveedor.dart';
import '../providers/proveedores_provider.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';

enum TipoOperacionStock { compra, ajuste }

class OperacionStockModal extends ConsumerStatefulWidget {
  const OperacionStockModal({
    super.key,
    required this.tipo,
    required this.productos,
    this.productoSeleccionado,
  });

  final TipoOperacionStock tipo;
  final List<ProductoInventario> productos;
  final ProductoInventario? productoSeleccionado;

  @override
  ConsumerState<OperacionStockModal> createState() => _OperacionStockModalState();
}

class _OperacionStockModalState extends ConsumerState<OperacionStockModal> {
  final _formKey = GlobalKey<FormState>();

  ProductoInventario? _producto;
  Proveedor? _proveedorSeleccionado;

  // Controladores Compra
  late final TextEditingController _cantidadCompra;
  late final TextEditingController _costoUnitarioCompra;

  // Controladores Ajuste
  late final TextEditingController _nuevaExistencia;
  String _motivoAjuste = 'Conteo físico de rutina';

  final List<String> _motivos = [
    'Conteo físico de rutina',
    'Producto dañado / vencido',
    'Merma o autoconsumo',
    'Corrección de registro previo',
    'Pérdida o faltante',
  ];

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _producto = widget.productoSeleccionado ??
        (widget.productos.isNotEmpty ? widget.productos.first : null);

    _cantidadCompra = TextEditingController();
    _costoUnitarioCompra = TextEditingController(
      text: _producto != null
          ? (_producto!.costoPromedio ?? _producto!.precioCompra).toStringAsFixed(2)
          : '',
    );
    _nuevaExistencia = TextEditingController(
      text: _producto != null ? _producto!.existencias.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _cantidadCompra.dispose();
    _costoUnitarioCompra.dispose();
    _nuevaExistencia.dispose();
    super.dispose();
  }

  void _onProductoCambiado(ProductoInventario? nuevo) {
    setState(() {
      _producto = nuevo;
      if (nuevo != null) {
        _costoUnitarioCompra.text =
            (nuevo.costoPromedio ?? nuevo.precioCompra).toStringAsFixed(2);
        _nuevaExistencia.text = nuevo.existencias.toStringAsFixed(0);
      }
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_producto == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final repo = ref.read(supabaseRepositoryProvider);

    try {
      if (widget.tipo == TipoOperacionStock.compra) {
        final cant = double.tryParse(_cantidadCompra.text.trim()) ?? 0;
        final costo = double.tryParse(_costoUnitarioCompra.text.trim()) ?? 0;

        String? prodId = _producto!.id;
        prodId ??= await repo.buscarOCrearProducto(
          nombre: _producto!.nombre,
          precioCompra: costo,
          precioVenta: _producto!.precioVenta,
        );

        if (prodId == null) {
          setState(() {
            _error = 'No se encontró el ID del producto.';
            _guardando = false;
          });
          return;
        }

        final compraId = await repo.registrarCompra(
          productoId: prodId,
          cantidad: cant,
          costoUnitario: costo,
          proveedor: _proveedorSeleccionado?.nombre ?? _producto!.proveedorNombre,
        );

        if (compraId == null) {
          setState(() {
            _error = 'No se pudo registrar la compra.';
            _guardando = false;
          });
          return;
        }
      } else {
        // Ajuste
        final nuevaCant = double.tryParse(_nuevaExistencia.text.trim()) ?? 0;
        bool ok = false;

        if (_producto!.id != null) {
          ok = await repo.ajustarInventarioConMotivo(
            productoId: _producto!.id!,
            cantidadObjetivo: nuevaCant,
            motivo: _motivoAjuste,
          );
        } else {
          ok = await repo.ajustarInventario(
            nombre: _producto!.nombre,
            cantidadObjetivo: nuevaCant,
          );
        }

        if (!ok) {
          setState(() {
            _error = 'No se pudo aplicar el ajuste de inventario.';
            _guardando = false;
          });
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Error en la operación: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esCompra = widget.tipo == TipoOperacionStock.compra;
    final proveedoresAsync = ref.watch(proveedoresProvider);

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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (esCompra ? LuminaColors.primary : Colors.amber.shade800)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      esCompra ? Icons.add_shopping_cart : Icons.tune,
                      color: esCompra ? LuminaColors.primary : Colors.amber.shade800,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esCompra ? 'Registrar Compra / Entrada' : 'Ajuste de Inventario / Merma',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          esCompra
                              ? 'Ingresa mercadería comprada al almacén'
                              : 'Cuadra existencias por conteo, daño o merma',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: LuminaColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LuminaColors.negative.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: LuminaColors.negative)),
                ),
                const SizedBox(height: 12),
              ],

              // Selector de Producto
              DropdownButtonFormField<ProductoInventario>(
                initialValue: _producto,
                decoration: const InputDecoration(
                  labelText: 'Producto a operar *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: widget.productos.map((prod) {
                  return DropdownMenuItem(
                    value: prod,
                    child: Text(
                      '${prod.nombre} (Stock: ${prod.existencias.toStringAsFixed(0)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onProductoCambiado,
                validator: (v) => v == null ? 'Selecciona un producto' : null,
              ),

              const SizedBox(height: 12),

              if (esCompra) ...[
                // Proveedor para la compra
                proveedoresAsync.maybeWhen(
                  data: (proveedores) {
                    return DropdownButtonFormField<Proveedor>(
                      initialValue: _proveedorSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor (opcional)',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sin proveedor específico'),
                        ),
                        ...proveedores.map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.nombre),
                            )),
                      ],
                      onChanged: (p) => setState(() => _proveedorSeleccionado = p),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cantidadCompra,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Cantidad *',
                          suffixText: _producto?.unidadMedida ?? 'uds',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa cantidad';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Mayor a 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costoUnitarioCompra,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Costo Unitario *',
                          prefixText: 'Q ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa costo';
                          final n = double.tryParse(v);
                          if (n == null || n < 0) return 'Válido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Sección de Ajuste / Merma
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LuminaColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Existencia registrada en sistema:'),
                      Text(
                        '${_producto?.existencias.toStringAsFixed(0) ?? 0} ${_producto?.unidadMedida ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nuevaExistencia,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Nueva Existencia Real / Contada *',
                    suffixText: _producto?.unidadMedida ?? 'uds',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa el stock físico';
                    final n = double.tryParse(v);
                    if (n == null || n < 0) return 'Mayor o igual a 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _motivoAjuste,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del Ajuste',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  items: _motivos.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (m) {
                    if (m != null) setState(() => _motivoAjuste = m);
                  },
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(
                    _guardando
                        ? 'Guardando...'
                        : esCompra
                            ? 'Confirmar Compra'
                            : 'Aplicar Ajuste de Stock',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
