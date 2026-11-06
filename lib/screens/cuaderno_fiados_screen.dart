import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/cuenta_por_cobrar.dart';
import '../providers/fiados_provider.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';

class CuadernoFiadosScreen extends ConsumerStatefulWidget {
  const CuadernoFiadosScreen({super.key});

  @override
  ConsumerState<CuadernoFiadosScreen> createState() => _CuadernoFiadosScreenState();
}

class _CuadernoFiadosScreenState extends ConsumerState<CuadernoFiadosScreen> {
  String _busqueda = '';
  String _filtroEstado = 'pendientes'; // 'todos', 'pendientes', 'pagados'

  @override
  Widget build(BuildContext context) {
    final fiadosAsync = ref.watch(fiadosProvider);

    return Scaffold(
      backgroundColor: LuminaColors.surface,
      appBar: AppBar(
        title: const Text('Cuaderno de Fiados'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(fiadosProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LuminaColors.primary,
        foregroundColor: LuminaColors.onPrimary,
        icon: const Icon(Icons.post_add),
        label: const Text('Nuevo Fiado'),
        onPressed: () => _abrirModalNuevoFiado(context),
      ),
      body: SafeArea(
        child: fiadosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    'No se pudieron cargar los fiados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$e',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LuminaColors.onSurfaceVariant,
                        ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(fiadosProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          data: (cuentas) {
            final pendientes = cuentas.where((c) => !c.estaPagado).toList();
            final totalPorCobrar = pendientes.fold<double>(
              0,
              (acc, c) => acc + c.saldoPendiente,
            );

            // Filtrar cuentas
            final filtradas = cuentas.where((c) {
              if (_filtroEstado == 'pendientes' && c.estaPagado) return false;
              if (_filtroEstado == 'pagados' && !c.estaPagado) return false;
              if (_busqueda.isNotEmpty) {
                final q = _busqueda.toLowerCase();
                final matchNombre = c.clienteNombre.toLowerCase().contains(q);
                final matchDesc = c.descripcion?.toLowerCase().contains(q) ?? false;
                if (!matchNombre && !matchDesc) return false;
              }
              return true;
            }).toList();

            return Column(
              children: [
                // KPI Header
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LuminaColors.primaryContainer,
                        LuminaColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: LuminaColors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Pendiente por Cobrar',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Q${totalPorCobrar.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pendientes.length} clientes con saldo pendiente',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Buscador y Filtros
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o detalle...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _busqueda = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),

                // Chips de Filtro
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('Pendientes (${pendientes.length})'),
                        selected: _filtroEstado == 'pendientes',
                        onSelected: (_) => setState(() => _filtroEstado = 'pendientes'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('Todos (${cuentas.length})'),
                        selected: _filtroEstado == 'todos',
                        onSelected: (_) => setState(() => _filtroEstado = 'todos'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('Pagados (${cuentas.length - pendientes.length})'),
                        selected: _filtroEstado == 'pagados',
                        onSelected: (_) => setState(() => _filtroEstado = 'pagados'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Lista de Fiados
                Expanded(
                  child: filtradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sentiment_satisfied_alt,
                                size: 56,
                                color: LuminaColors.onSurfaceVariant.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _busqueda.isNotEmpty
                                    ? 'No se encontraron fiados con ese criterio'
                                    : '¡No hay deudas en esta sección!',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: filtradas.length,
                          itemBuilder: (context, index) {
                            final cuenta = filtradas[index];
                            return _FiadoCard(
                              cuenta: cuenta,
                              onAbonar: () => _abrirModalAbono(context, cuenta),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _abrirModalNuevoFiado(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.post_add, color: LuminaColors.primary),
                        const SizedBox(width: 8),
                        Text('Anotar Nuevo Fiado', style: LuminaTextStyles.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Cliente *',
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Ej. Doña Carmen',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del cliente' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto a Fiar *',
                        prefixText: 'Q ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v?.trim() ?? '');
                        if (val == null || val <= 0) return 'Ingresa un monto mayor a 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Detalle o mercadería fiada',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                        hintText: 'Ej. 2 leches y 1 bolsa de pan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => guardando = true);
                                final repo = ref.read(supabaseRepositoryProvider);
                                final monto = double.parse(montoCtrl.text.trim());
                                final ok = await repo.registrarFiado(
                                  clienteNombre: nombreCtrl.text.trim(),
                                  monto: monto,
                                  clienteTelefono:
                                      telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
                                  descripcion:
                                      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (ok != null) {
                                  ref.invalidate(fiadosProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✓ Fiado registrado en el cuaderno')),
                                    );
                                  }
                                }
                              },
                        child: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar Fiado'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirModalAbono(BuildContext context, CuentaPorCobrar cuenta) {
    final formKey = GlobalKey<FormState>();
    final montoCtrl = TextEditingController(text: cuenta.saldoPendiente.toStringAsFixed(2));
    final notasCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments, color: LuminaColors.positive),
                        const SizedBox(width: 8),
                        Text('Registrar Abono / Pago', style: LuminaTextStyles.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cliente: ${cuenta.clienteNombre} • Saldo actual: Q${cuenta.saldoPendiente.toStringAsFixed(2)}',
                      style: LuminaTextStyles.bodyMedium.copyWith(color: LuminaColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto que abona el cliente *',
                        prefixText: 'Q ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v?.trim() ?? '');
                        if (val == null || val <= 0) return 'Ingresa un monto válido';
                        if (val > cuenta.saldoPendiente) {
                          return 'El abono no puede ser mayor al saldo (Q${cuenta.saldoPendiente.toStringAsFixed(2)})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Botón para liquidar saldo completo con un toque
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Liquidar saldo total'),
                        onPressed: () {
                          montoCtrl.text = cuenta.saldoPendiente.toStringAsFixed(2);
                        },
                      ),
                    ),
                    TextFormField(
                      controller: notasCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notas del abono (opcional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: LuminaColors.positive),
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => guardando = true);
                                final repo = ref.read(supabaseRepositoryProvider);
                                final monto = double.parse(montoCtrl.text.trim());
                                final ok = await repo.registrarAbonoFiado(
                                  cuentaId: cuenta.id,
                                  monto: monto,
                                  notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (ok) {
                                  ref.invalidate(fiadosProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✓ Abono registrado e ingresado a caja')),
                                    );
                                  }
                                }
                              },
                        child: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Confirmar Abono'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FiadoCard extends StatelessWidget {
  const _FiadoCard({
    required this.cuenta,
    required this.onAbonar,
  });

  final CuentaPorCobrar cuenta;
  final VoidCallback onAbonar;

  @override
  Widget build(BuildContext context) {
    final pagado = cuenta.montoTotal - cuenta.saldoPendiente;
    final porcentaje = cuenta.montoTotal > 0
        ? (pagado / cuenta.montoTotal).clamp(0.0, 1.0)
        : 1.0;
    final esAlerta = cuenta.diasDeuda >= 7 && !cuenta.estaPagado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esAlerta ? Colors.amber.shade400 : LuminaColors.outlineVariant,
          width: esAlerta ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cuenta.clienteNombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cuenta.estaPagado
                      ? LuminaColors.positive.withValues(alpha: 0.15)
                      : (esAlerta
                          ? Colors.amber.shade100
                          : LuminaColors.surfaceContainerHigh),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cuenta.estaPagado
                      ? 'PAGADO'
                      : (esAlerta
                          ? 'Atraso: ${cuenta.diasDeuda}d'
                          : '${cuenta.diasDeuda} días'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cuenta.estaPagado
                        ? LuminaColors.positive
                        : (esAlerta ? Colors.amber.shade900 : LuminaColors.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
          if (cuenta.descripcion != null && cuenta.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              cuenta.descripcion!,
              style: TextStyle(fontSize: 13, color: LuminaColors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fecha: ${DateFormat('dd/MM/yyyy').format(cuenta.fecha)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Total fiado: Q${cuenta.montoTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: LuminaColors.surfaceContainerHigh,
              color: cuenta.estaPagado ? LuminaColors.positive : LuminaColors.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo pendiente', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    'Q${cuenta.saldoPendiente.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: cuenta.estaPagado ? LuminaColors.positive : LuminaColors.onSurface,
                    ),
                  ),
                ],
              ),
              if (!cuenta.estaPagado)
                FilledButton.tonalIcon(
                  onPressed: onAbonar,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Abonar / Pagar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
