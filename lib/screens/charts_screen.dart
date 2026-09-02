import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flujo_caja.dart';
import '../models/resumen_analisis.dart';
import '../models/totales_mes.dart';
import '../providers/dashboard_provider.dart';
import '../services/supabase_repository.dart';
import '../theme/lumina_theme.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key, required this.repo, required this.dashboard});

  final FinanzasRepository repo;
  final DashboardData dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gráficas')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        color: LuminaColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ResumenMesCard(totales: dashboard.totales),
            const SizedBox(height: 20),
            Text(
              'Flujo diario',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _BarChart(flujo: dashboard.flujo),
            const SizedBox(height: 20),
            Text(
              'Ingresos vs Egresos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _IngresosEgresosChart(
              ingresos: dashboard.totales.ingresos,
              egresos: dashboard.totales.egresos,
            ),
            const SizedBox(height: 20),
            Text(
              'Por categoría',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _CategoriasChart(resumen: dashboard.resumen),
          ],
        ),
      ),
    );
  }
}

class _ResumenMesCard extends StatelessWidget {
  const _ResumenMesCard({required this.totales});

  final TotalesMes totales;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LuminaColors.primary, LuminaColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(LuminaRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance del mes',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Q${totales.balance.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(color: Colors.white, fontSize: 34),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniDato(
                label: 'Ingresos',
                monto: totales.ingresos,
                color: LuminaColors.tertiaryFixedDim,
              ),
              const SizedBox(width: 20),
              _miniDato(
                label: 'Egresos',
                monto: totales.egresos,
                color: LuminaColors.negative,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniDato({
    required String label,
    required double monto,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Q${monto.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.flujo});

  final List<FlujoDia> flujo;

  @override
  Widget build(BuildContext context) {
    final ordenados = flujo.reversed.toList();

    if (ordenados.isEmpty) {
      return _EmptyCard();
    }

    var maxValor = 1.0;
    for (final d in ordenados) {
      if (d.ingresos > maxValor) maxValor = d.ingresos;
      if (d.egresos > maxValor) maxValor = d.egresos;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _leyenda(color: LuminaColors.primary, label: 'Egresos'),
              const SizedBox(width: 16),
              _leyenda(
                color: LuminaColors.secondaryContainer,
                label: 'Ingresos',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final dia in ordenados)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: LuminaColors.secondaryContainer,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                    height: 100 * (dia.ingresos / maxValor),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: LuminaColors.primary,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                    height: 100 * (dia.egresos / maxValor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('d/M').format(dia.fecha),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: LuminaColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _IngresosEgresosChart extends StatelessWidget {
  const _IngresosEgresosChart({required this.ingresos, required this.egresos});

  final double ingresos;
  final double egresos;

  @override
  Widget build(BuildContext context) {
    final total = ingresos + egresos;
    final pctIngresos = total > 0 ? ingresos / total : 0.0;
    final pctEgresos = total > 0 ? egresos / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(LuminaRadii.pill),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: (pctIngresos * 1000).round(),
                    child: Container(color: LuminaColors.positive),
                  ),
                  Expanded(
                    flex: (pctEgresos * 1000).round(),
                    child: Container(color: LuminaColors.negative),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dato(
                color: LuminaColors.positive,
                label: 'Ingresos',
                monto: ingresos,
                pct: pctIngresos,
              ),
              _dato(
                color: LuminaColors.negative,
                label: 'Egresos',
                monto: egresos,
                pct: pctEgresos,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato({
    required Color color,
    required String label,
    required double monto,
    required double pct,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: LuminaColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Q${monto.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}

class _CategoriasChart extends StatelessWidget {
  const _CategoriasChart({required this.resumen});

  final ResumenAnalisis resumen;

  static const _colores = [
    LuminaColors.primary,
    LuminaColors.tertiaryContainer,
    LuminaColors.secondaryContainer,
    LuminaColors.primaryContainer,
    LuminaColors.tertiaryFixedDim,
    LuminaColors.secondaryFixedDim,
  ];

  @override
  Widget build(BuildContext context) {
    if (resumen.porCategoria.isEmpty) {
      return const _EmptyCard();
    }

    var maxTotal = 0.0;
    for (final c in resumen.porCategoria) {
      if (c.total > maxTotal) maxTotal = c.total;
    }
    if (maxTotal <= 0) maxTotal = 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < resumen.porCategoria.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BarraCategoria(
                categoria: resumen.porCategoria[i],
                color: _colores[i % _colores.length],
                proporcion: resumen.porCategoria[i].total / maxTotal,
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraCategoria extends StatelessWidget {
  const _BarraCategoria({
    required this.categoria,
    required this.color,
    required this.proporcion,
  });

  final ResumenCategoria categoria;
  final Color color;
  final double proporcion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                categoria.nombre,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Q${categoria.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(LuminaRadii.pill),
          child: LinearProgressIndicator(
            value: proporcion.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: LuminaColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Text(
        'Aún no hay datos para graficar.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: LuminaColors.onSurfaceVariant),
      ),
    );
  }
}
