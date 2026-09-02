import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/listado_transaccion.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(supabaseRepositoryProvider);

    return SafeArea(
      child: FutureBuilder(
        future: repo.listadoTransacciones(limite: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Mensaje(texto: 'No se pudo cargar el historial.');
          }
          final lista = (snapshot.data ?? []).toList();
          return _ListaTransacciones(lista: lista);
        },
      ),
    );
  }
}

class _ListaTransacciones extends StatelessWidget {
  const _ListaTransacciones({required this.lista});

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
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                    'Balance del mes',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Q${balance.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(color: LuminaColors.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: LuminaColors.primaryContainer,
                  borderRadius: BorderRadius.circular(LuminaRadii.pill),
                ),
                child: Text(
                  '${lista.length} movimientos',
                  style: Theme.of(context).textTheme.labelSmall
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: lista.length,
                  itemBuilder: (context, index) =>
                      _MovimientoItem(transaccion: lista[index]),
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
                  : LuminaColors.tertiaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(LuminaRadii.lg),
            ),
            child: Icon(
              isIngreso ? Icons.payments : Icons.storefront,
              color: isIngreso
                  ? LuminaColors.positive
                  : LuminaColors.tertiaryContainer,
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
              color: isIngreso
                  ? LuminaColors.positive
                  : LuminaColors.onTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: LuminaColors.onSurfaceVariant),
        ),
      ),
    );
  }
}
