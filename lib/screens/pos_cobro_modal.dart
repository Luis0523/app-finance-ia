import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item_venta_pos.dart';
import '../providers/inventario_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';

class PosCobroModal extends ConsumerStatefulWidget {
  const PosCobroModal({
    super.key,
    required this.items,
    required this.total,
  });

  final List<ItemVentaPos> items;
  final double total;

  static Future<bool?> cobrar(
    BuildContext context, {
    required List<ItemVentaPos> items,
    required double total,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosCobroModal(items: items, total: total),
    );
  }

  @override
  ConsumerState<PosCobroModal> createState() => _PosCobroModalState();
}

class _PosCobroModalState extends ConsumerState<PosCobroModal> {
  String _metodoPago = 'efectivo'; // efectivo, tarjeta, credito
  late final TextEditingController _montoRecibidoController;
  late final TextEditingController _clienteFiadoController;
  late final TextEditingController _telefonoFiadoController;

  bool _procesando = false;
  bool _ventaExitosa = false;
  String? _error;

  double get _montoRecibido =>
      double.tryParse(_montoRecibidoController.text.trim()) ?? 0;

  double get _cambio =>
      _montoRecibido >= widget.total ? _montoRecibido - widget.total : 0;

  double get _faltante =>
      _montoRecibido < widget.total ? widget.total - _montoRecibido : 0;

  @override
  void initState() {
    super.initState();
    _montoRecibidoController = TextEditingController(
      text: widget.total.toStringAsFixed(2),
    );
    _clienteFiadoController = TextEditingController();
    _telefonoFiadoController = TextEditingController();
  }

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    _clienteFiadoController.dispose();
    _telefonoFiadoController.dispose();
    super.dispose();
  }

  List<double> _sugerenciasBilletes(double total) {
    final sugerencias = <double>{total};
    for (final billete in [20.0, 50.0, 100.0, 200.0]) {
      if (billete >= total) sugerencias.add(billete);
    }
    final lista = sugerencias.toList()..sort();
    return lista;
  }

  Future<void> _finalizarVenta() async {
    if (_metodoPago == 'efectivo' && _montoRecibido < widget.total) {
      setState(() => _error = 'El monto recibido es menor al total de la cuenta');
      return;
    }

    if (_metodoPago == 'credito' && _clienteFiadoController.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el nombre del cliente para anotar el fiado');
      return;
    }

    setState(() {
      _procesando = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final ok = await repo.registrarVentaPos(
        items: widget.items,
        metodoPago: _metodoPago,
      );

      if (ok) {
        if (_metodoPago == 'credito') {
          final cliente = _clienteFiadoController.text.trim();
          final tel = _telefonoFiadoController.text.trim();
          await repo.registrarFiado(
            clienteNombre: cliente,
            monto: widget.total,
            clienteTelefono: tel.isEmpty ? null : tel,
            descripcion: 'Venta POS (${widget.items.length} productos)',
          );
        }

        // Refrescar inventario y métricas en toda la app
        ref.invalidate(inventarioProvider);
        ref.read(posProvider.notifier).limpiarCarrito();

        setState(() {
          _procesando = false;
          _ventaExitosa = true;
        });
      } else {
        setState(() {
          _procesando = false;
          _error = 'No se pudo completar el registro de la venta';
        });
      }
    } catch (e) {
      setState(() {
        _procesando = false;
        _error = 'Error al registrar venta: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: LuminaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
      ),
      child: _ventaExitosa ? _buildTicketExito(theme) : _buildFormularioCobro(theme),
    );
  }

  Widget _buildFormularioCobro(ThemeData theme) {
    final billetes = _sugerenciasBilletes(widget.total);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cobrar Venta', style: theme.textTheme.headlineMedium),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tarjeta de Total a Cobrar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LuminaColors.primary.withValues(alpha: 0.12),
                  LuminaColors.surfaceContainerHigh,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LuminaColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'TOTAL A COBRAR',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: LuminaColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Q${widget.total.toStringAsFixed(2)}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: LuminaColors.onSurface,
                  ),
                ),
                Text(
                  '${widget.items.length} productos en la cuenta',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: LuminaColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selector de Método de Pago
          Text(
            'Forma de pago',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetodoPagoChip(
                  icono: Icons.payments_outlined,
                  etiqueta: 'Efectivo',
                  seleccionado: _metodoPago == 'efectivo',
                  onTap: () => setState(() => _metodoPago = 'efectivo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetodoPagoChip(
                  icono: Icons.credit_card_outlined,
                  etiqueta: 'Tarjeta',
                  seleccionado: _metodoPago == 'tarjeta',
                  onTap: () => setState(() => _metodoPago = 'tarjeta'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetodoPagoChip(
                  icono: Icons.menu_book_outlined,
                  etiqueta: 'Fiar / Crédito',
                  seleccionado: _metodoPago == 'credito',
                  onTap: () => setState(() => _metodoPago = 'credito'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calculadora de Efectivo y Vuelto
          if (_metodoPago == 'efectivo') ...[
            TextFormField(
              controller: _montoRecibidoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto recibido del cliente *',
                prefixText: 'Q ',
                prefixIcon: Icon(Icons.money),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            // Chips rápidos de billetes
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: billetes.map((b) {
                return ActionChip(
                  label: Text('Q${b.toStringAsFixed(b % 1 == 0 ? 0 : 2)}'),
                  onPressed: () {
                    setState(() {
                      _montoRecibidoController.text = b.toStringAsFixed(2);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Tarjeta de Cambio / Vuelto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _montoRecibido >= widget.total
                    ? LuminaColors.positive.withValues(alpha: 0.1)
                    : LuminaColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _montoRecibido >= widget.total
                        ? 'Cambio / Vuelto a entregar:'
                        : 'Monto faltante:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _montoRecibido >= widget.total
                          ? LuminaColors.positive
                          : LuminaColors.negative,
                    ),
                  ),
                  Text(
                    _montoRecibido >= widget.total
                        ? 'Q${_cambio.toStringAsFixed(2)}'
                        : '-Q${_faltante.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _montoRecibido >= widget.total
                          ? LuminaColors.positive
                          : LuminaColors.negative,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_metodoPago == 'tarjeta') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LuminaColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LuminaColors.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.contactless, color: LuminaColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cobro con POS / Tarjeta',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Procesa el cobro por Q${widget.total.toStringAsFixed(2)} en tu terminal o POS físico y confirma la venta.',
                          style: theme.textTheme.bodySmall?.copyWith(color: LuminaColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_metodoPago == 'credito') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LuminaColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LuminaColors.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: LuminaColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Anotar en Cuaderno de Fiados',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _clienteFiadoController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente *',
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'Ej. Doña Carmen',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _telefonoFiadoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se descontará el inventario y se registrará la deuda de Q${widget.total.toStringAsFixed(2)} por cobrar.',
                    style: theme.textTheme.bodySmall?.copyWith(color: LuminaColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: LuminaColors.negative)),
          ],

          const SizedBox(height: 22),

          // Botón Confirmar
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: LuminaColors.primary,
                foregroundColor: LuminaColors.onPrimary,
              ),
              onPressed: _procesando ? null : _finalizarVenta,
              child: _procesando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmar Cobro y Descontar Stock',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketExito(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: LuminaColors.positive, size: 64),
        const SizedBox(height: 10),
        Text(
          '¡Venta Registrada Exitosamente!',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'El inventario se ha descontado y la ganancia fue registrada en tu Kardex.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: LuminaColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LuminaColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total cobrado:'),
                  Text(
                    'Q${widget.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Método de pago:'),
                  Text(
                    _metodoPago.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_metodoPago == 'efectivo') ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monto recibido:'),
                    Text('Q${_montoRecibido.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cambio entregado:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Q${_cambio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LuminaColors.positive,
                      ),
                    ),
                  ],
                ),
              ],
              if (_metodoPago == 'credito') ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cliente deudor:'),
                    Text(
                      _clienteFiadoController.text.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Registrado en:'),
                    const Text(
                      'Cuaderno de Fiados',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Comenzar Nueva Venta'),
          ),
        ),
      ],
    );
  }
}

class _MetodoPagoChip extends StatelessWidget {
  const _MetodoPagoChip({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? LuminaColors.primary.withValues(alpha: 0.15)
              : LuminaColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? LuminaColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              size: 22,
              color: seleccionado ? LuminaColors.primary : LuminaColors.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 12,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                color: seleccionado ? LuminaColors.primary : LuminaColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
