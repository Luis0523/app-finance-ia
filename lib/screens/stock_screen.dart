import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/producto_inventario.dart';
import '../providers/inventario_provider.dart';
import '../providers/supabase_provider.dart';
import '../services/supabase_repository.dart';
import '../theme/lumina_theme.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventario = ref.watch(inventarioProvider);

    return SafeArea(
      child: Column(
        children: [
          _Header(
            onRecargar: () => ref.invalidate(inventarioProvider),
            onAgregar: () => _abrirFormulario(context, ref, producto: null),
          ),
          Expanded(
            child: inventario.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                onRetry: () => ref.invalidate(inventarioProvider),
              ),
              data: (productos) => _ListaProductos(
                productos: productos,
                onRefresh: () => ref.refresh(inventarioProvider.future),
                onEditar: (producto) =>
                    _abrirFormulario(context, ref, producto: producto),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    WidgetRef ref, {
    required ProductoInventario? producto,
  }) async {
    final repo = ref.read(supabaseRepositoryProvider);
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LuminaColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LuminaRadii.card),
        ),
      ),
      builder: (_) => _ProductoForm(repo: repo, producto: producto),
    );

    if (guardado == true) {
      ref.invalidate(inventarioProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              producto == null
                  ? 'Producto agregado al inventario.'
                  : 'Producto actualizado.',
            ),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRecargar, required this.onAgregar});

  final VoidCallback onRecargar;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Inventario',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          IconButton(
            onPressed: onRecargar,
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            color: LuminaColors.primary,
          ),
          TextButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
          ),
        ],
      ),
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

class _ListaProductos extends StatelessWidget {
  const _ListaProductos({
    required this.productos,
    required this.onRefresh,
    required this.onEditar,
  });

  final List<ProductoInventario> productos;
  final Future<void> Function() onRefresh;
  final ValueChanged<ProductoInventario> onEditar;

  @override
  Widget build(BuildContext context) {
    final valorTotal = productos.fold<double>(
      0,
      (acc, p) => acc + p.valorTotal,
    );

    if (productos.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: LuminaColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: _VacioMessage(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: LuminaColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _CardValor(valorTotal: valorTotal, cantidad: productos.length),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final producto = productos[index];
              return _ProductoCard(
                producto: producto,
                onTap: () => onEditar(producto),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VacioMessage extends StatelessWidget {
  const _VacioMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 56,
          color: LuminaColors.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'Aún no hay productos en tu inventario.\n'
          'Toca "Agregar" o registra una compra con el asistente.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: LuminaColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CardValor extends StatelessWidget {
  const _CardValor({required this.valorTotal, required this.cantidad});

  final double valorTotal;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valor del inventario',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Q${valorTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(color: LuminaColors.primary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: LuminaColors.primaryContainer,
              borderRadius: BorderRadius.circular(LuminaRadii.pill),
            ),
            child: Text(
              '$cantidad productos',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: LuminaColors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({required this.producto, required this.onTap});

  final ProductoInventario producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final agotado = (producto.existencias <= 0);
    final bajo =
        !agotado &&
        producto.stockMinimo != null &&
        producto.existencias <= producto.stockMinimo!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuminaRadii.card),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LuminaColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(LuminaRadii.card),
          border: Border.all(color: LuminaColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LuminaColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(LuminaRadii.lg),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: LuminaColors.primary.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: LuminaColors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              producto.nombre,
              style: Theme.of(context).textTheme.labelLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${producto.precioVenta.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: LuminaColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${producto.existencias.toStringAsFixed(0)} u.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: agotado || bajo
                              ? (agotado
                                    ? LuminaColors.error
                                    : LuminaColors.tertiary)
                              : LuminaColors.onSurfaceVariant,
                          fontWeight: (agotado || bajo)
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (producto.utilidadUnitaria != null)
                  _ChipMargen(margen: producto.utilidadUnitaria!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipMargen extends StatelessWidget {
  const _ChipMargen({required this.margen});

  final double margen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LuminaColors.tertiaryFixedDim.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(LuminaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, size: 12, color: LuminaColors.tertiary),
          const SizedBox(width: 2),
          Text(
            '+${margen.toStringAsFixed(0)}% Mg.',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: LuminaColors.tertiary),
          ),
        ],
      ),
    );
  }
}

class _ProductoForm extends StatefulWidget {
  const _ProductoForm({required this.repo, this.producto});

  final FinanzasRepository repo;
  final ProductoInventario? producto;

  @override
  State<_ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<_ProductoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _precioCompra;
  late final TextEditingController _precioVenta;
  late final TextEditingController _existencias;
  late final TextEditingController _stockMinimo;
  bool _guardando = false;
  String? _error;

  bool get _esNuevo => widget.producto == null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
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
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precioCompra.dispose();
    _precioVenta.dispose();
    _existencias.dispose();
    _stockMinimo.dispose();
    super.dispose();
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

      if (_esNuevo) {
        final id = await widget.repo.buscarOCrearProducto(
          nombre: nombre,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
        );
        if (id == null) {
          setState(() {
            _error = 'No se pudo crear el producto.';
            _guardando = false;
          });
          return;
        }
        if (stockMinimo != null) {
          await widget.repo.actualizarProducto(
            nombre: nombre,
            stockMinimo: stockMinimo,
          );
        }
      } else {
        final ok = await widget.repo.actualizarProducto(
          nombre: nombre,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          stockMinimo: stockMinimo,
        );
        if (!ok) {
          setState(() {
            _error = 'No se encontró el producto para actualizar.';
            _guardando = false;
          });
          return;
        }
      }

      if (existencias != null) {
        await widget.repo.ajustarInventario(
          nombre: nombre,
          cantidadObjetivo: existencias,
        );
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

  double? _parsar(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final textoForm = Theme.of(context).textTheme.labelMedium;
    final esNuevo = _esNuevo;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
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
                      esNuevo ? 'Agregar producto' : 'Editar producto',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    color: LuminaColors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                esNuevo
                    ? 'Registra un producto manualmente en tu inventario.'
                    : 'Actualiza los datos de ${widget.producto!.nombre}.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: LuminaColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombre,
                enabled: esNuevo,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  hintText: 'Ej. Gaseosas, Bananos, Harina',
                ),
                validator: (v) {
                  if (esNuevo && (v == null || v.trim().isEmpty)) {
                    return 'Escribe el nombre del producto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _precioCompra,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Precio compra',
                        prefixText: 'Q ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _precioVenta,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Precio venta',
                        prefixText: 'Q ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _existencias,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Existencias',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stockMinimo,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Stock mínimo',
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_esNuevo)
                Text(
                  'El stock mínimo sirve para avisarte cuando el producto se '
                  'esté agotando.',
                  style: textoForm?.copyWith(
                    color: LuminaColors.onSurfaceVariant,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: LuminaColors.error),
                ),
              ],
              const SizedBox(height: 20),
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
                      : Text(esNuevo ? 'Agregar producto' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
