import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/listado_transaccion.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';
import 'cuaderno_fiados_screen.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(supabaseRepositoryProvider);

    return Scaffold(
      backgroundColor: LuminaColors.surface,
      appBar: AppBar(
        title: const Text('Historial y Gastos'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: LuminaColors.primary,
          unselectedLabelColor: LuminaColors.onSurfaceVariant,
          indicatorColor: LuminaColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Ventas'),
            Tab(text: 'Gastos'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cuaderno de Fiados',
            icon: const Icon(Icons.menu_book),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CuadernoFiadosScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          // Si está en la pestaña de gastos (índice 2), mostrar botón de nuevo gasto
          if (_tabController.index == 2) {
            return FloatingActionButton.extended(
              backgroundColor: LuminaColors.error,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Registrar Gasto'),
              onPressed: () => _abrirModalNuevoGasto(context),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: SafeArea(
        child: FutureBuilder<List<ListadoTransaccion>>(
          future: repo.listadoTransacciones(limite: 150),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('No se pudo cargar el historial.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final lista = snapshot.data ?? [];
            final ingresos = lista.where((t) => t.tipo == 'ingreso').toList();
            final egresos = lista.where((t) => t.tipo == 'egreso').toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _TabTodos(lista: lista),
                _TabVentas(ingresos: ingresos),
                _TabGastos(
                  egresos: egresos,
                  onNuevoGasto: () => _abrirModalNuevoGasto(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _abrirModalNuevoGasto(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String categoria = 'Gastos operativos';
    String metodo = 'Efectivo';
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LuminaColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.money_off, color: LuminaColors.error),
                        ),
                        const SizedBox(width: 12),
                        Text('Registrar Nuevo Gasto', style: LuminaTextStyles.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto del Gasto *',
                        prefixText: 'Q ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v?.trim() ?? '');
                        if (val == null || val <= 0) return 'Ingresa un monto válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del gasto *',
                        prefixIcon: Icon(Icons.description_outlined),
                        hintText: 'Ej. Pago de luz, Transporte de mercadería, Alquiler',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Describe el gasto' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoría Contable',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Gastos operativos', child: Text('Gastos operativos (Luz, agua, alquiler)')),
                        DropdownMenuItem(value: 'Costos de venta', child: Text('Costos de venta (Insumos, empaques)')),
                        DropdownMenuItem(value: 'Gastos administrativos', child: Text('Gastos administrativos (Papelería, etc.)')),
                        DropdownMenuItem(value: 'Otros gastos', child: Text('Otros gastos (Imprevistos, varios)')),
                        DropdownMenuItem(value: 'Retiros personales', child: Text('Retiros personales (Dueño)')),
                      ],
                      onChanged: (v) => setModalState(() => categoria = v ?? categoria),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: metodo,
                      decoration: const InputDecoration(
                        labelText: 'Medio de Pago',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo de caja')),
                        DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia bancaria')),
                        DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta de débito/crédito')),
                      ],
                      onChanged: (v) => setModalState(() => metodo = v ?? metodo),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: LuminaColors.error),
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => guardando = true);
                                final repo = ref.read(supabaseRepositoryProvider);
                                final monto = double.parse(montoCtrl.text.trim());
                                final id = await repo.registrarGastoManual(
                                  monto: monto,
                                  categoriaNivel1: categoria,
                                  descripcion: descCtrl.text.trim(),
                                  metodoPago: metodo,
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (id != null) {
                                  setState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✓ Gasto registrado exitosamente')),
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
                            : const Text('Guardar Gasto'),
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

class _TabTodos extends StatelessWidget {
  const _TabTodos({required this.lista});
  final List<ListadoTransaccion> lista;

  @override
  Widget build(BuildContext context) {
    final balance = lista.fold<double>(
      0,
      (acc, t) => acc + (t.tipo == 'ingreso' ? t.monto : -t.monto),
    );

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  Text('Balance General', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Q${balance.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: balance >= 0 ? LuminaColors.primary : LuminaColors.error,
                        ),
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
                  '${lista.length} movimientos',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: LuminaColors.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Aún no hay movimientos registrados.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: lista.length,
                  itemBuilder: (context, index) => _MovimientoItem(transaccion: lista[index]),
                ),
        ),
      ],
    );
  }
}

class _TabVentas extends StatelessWidget {
  const _TabVentas({required this.ingresos});
  final List<ListadoTransaccion> ingresos;

  @override
  Widget build(BuildContext context) {
    final totalVentas = ingresos.fold<double>(0, (acc, t) => acc + t.monto);
    final totalGanancia = ingresos.fold<double>(
      0,
      (acc, t) => acc + (t.utilidad ?? 0.0),
    );

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LuminaColors.positive.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuminaColors.positive.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Ventas', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    'Q${totalVentas.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: LuminaColors.positive,
                    ),
                  ),
                ],
              ),
              if (totalGanancia > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ganancia estimada', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      'Q${totalGanancia.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: ingresos.isEmpty
              ? const Center(child: Text('No hay ventas registradas.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: ingresos.length,
                  itemBuilder: (context, index) => _MovimientoItem(transaccion: ingresos[index]),
                ),
        ),
      ],
    );
  }
}

class _TabGastos extends StatelessWidget {
  const _TabGastos({
    required this.egresos,
    required this.onNuevoGasto,
  });

  final List<ListadoTransaccion> egresos;
  final VoidCallback onNuevoGasto;

  @override
  Widget build(BuildContext context) {
    final totalGastos = egresos.fold<double>(0, (acc, t) => acc + t.monto);

    // Agrupar por categoría
    final porCategoria = <String, double>{};
    for (final e in egresos) {
      porCategoria[e.categoria] = (porCategoria[e.categoria] ?? 0.0) + e.monto;
    }

    return Column(
      children: [
        // KPI de Gastos
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LuminaColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuminaColors.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Gastos del Mes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    'Q${totalGastos.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: LuminaColors.error,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LuminaColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${egresos.length} gastos',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: LuminaColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Desglose por Categorías
        if (porCategoria.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LuminaColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LuminaColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desglose por Categoría',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: porCategoria.entries.map((entry) {
                    final pct = totalGastos > 0 ? (entry.value / totalGastos * 100) : 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: LuminaColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.key}: Q${entry.value.toStringAsFixed(2)} (${pct.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        // Lista de Gastos
        Expanded(
          child: egresos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.thumb_up_alt_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('¡No hay gastos registrados!'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onNuevoGasto,
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar Primer Gasto'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: egresos.length,
                  itemBuilder: (context, index) => _MovimientoItem(transaccion: egresos[index]),
                ),
        ),
      ],
    );
  }
}

class _MovimientoItem extends StatelessWidget {
  const _MovimientoItem({required this.transaccion});
  final ListadoTransaccion transaccion;

  @override
  Widget build(BuildContext context) {
    final isIngreso = transaccion.tipo == 'ingreso';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(LuminaRadii.xl),
        border: Border.all(color: LuminaColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isIngreso
                  ? const Color(0xFFE6F4EA)
                  : LuminaColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(LuminaRadii.lg),
            ),
            child: Icon(
              isIngreso ? Icons.payments : Icons.receipt_long,
              color: isIngreso ? LuminaColors.positive : LuminaColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaccion.descripcion ?? transaccion.categoria,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaccion.categoria} · ${DateFormat('d MMM, HH:mm').format(transaccion.fecha)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIngreso ? '+' : '-'}Q${transaccion.monto.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isIngreso ? LuminaColors.positive : LuminaColors.error,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
