import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flujo_caja.dart';
import '../models/listado_transaccion.dart';
import '../providers/dashboard_provider.dart';
import '../providers/negocio_provider.dart';
import '../providers/supabase_provider.dart';
import '../theme/lumina_theme.dart';
import 'charts_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenChat});

  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final negocio = ref.watch(negocioNombreProvider);
    final repo = ref.watch(supabaseRepositoryProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        color: LuminaColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            _Header(nombre: negocio.value ?? 'Mi negocio'),
            const SizedBox(height: 24),
            if (dashboard.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (dashboard.hasError)
              _ErrorCard(
                mensaje: 'No se pudieron cargar los datos.',
                onRetry: () => ref.invalidate(dashboardProvider),
              )
            else if (dashboard.value?.vacio ?? true)
              _EmptyCard(onOpenChat: onOpenChat)
            else ...[
              _BalanceCard(dashboard: dashboard.value!),
              const SizedBox(height: 12),
              _ResumenCards(dashboard: dashboard.value!),
              const SizedBox(height: 24),
              _ActividadHeader(
                onVerGraficas: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChartsScreen(repo: repo, dashboard: dashboard.value!),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ActividadChart(flujo: dashboard.value!.flujo),
              const SizedBox(height: 24),
              _MovimientosHeader(onOpenChat: onOpenChat),
              const SizedBox(height: 8),
              ...dashboard.value!.recientes.map(
                (t) => _MovimientoItem(transaccion: t),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, ¿cómo va tu negocio hoy?',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          nombre,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: LuminaColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.dashboard});

  final dynamic dashboard;

  @override
  Widget build(BuildContext context) {
    final balance = dashboard.totales.balance as double;
    final ingresos = dashboard.totales.ingresos as double;
    final pct = ingresos > 0
        ? (balance / ingresos * 100).clamp(0, 999).toStringAsFixed(0)
        : '0';

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
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                'Balance General',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Q${balance.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(color: Colors.white, fontSize: 36),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                size: 16,
                color: LuminaColors.tertiaryFixedDim,
              ),
              const SizedBox(width: 4),
              Text(
                '+$pct% este mes',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: LuminaColors.tertiaryFixedDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenCards extends StatelessWidget {
  const _ResumenCards({required this.dashboard});

  final dynamic dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ResumenCard(
            icon: Icons.arrow_downward,
            iconColor: LuminaColors.primary,
            iconBg: LuminaColors.primary.withValues(alpha: 0.1),
            label: 'Ingresos',
            monto: (dashboard.totales.ingresos as double),
            textColor: LuminaColors.positive,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ResumenCard(
            icon: Icons.arrow_upward,
            iconColor: LuminaColors.error,
            iconBg: LuminaColors.error.withValues(alpha: 0.1),
            label: 'Egresos',
            monto: (dashboard.totales.egresos as double),
            textColor: LuminaColors.negative,
          ),
        ),
      ],
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.monto,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final double monto;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            'Q${monto.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _ActividadHeader extends StatelessWidget {
  const _ActividadHeader({required this.onVerGraficas});

  final VoidCallback onVerGraficas;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Actividad', style: Theme.of(context).textTheme.headlineMedium),
        TextButton(onPressed: onVerGraficas, child: const Text('Ver gráficas')),
      ],
    );
  }
}

class _ActividadChart extends StatelessWidget {
  const _ActividadChart({required this.flujo});

  final List<FlujoDia> flujo;

  @override
  Widget build(BuildContext context) {
    final ultimos7 = flujo.take(7).toList().reversed.toList();

    if (ultimos7.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LuminaColors.surfaceContainer,
          borderRadius: BorderRadius.circular(LuminaRadii.card),
          border: Border.all(color: LuminaColors.cardBorder),
        ),
        child: const Text('Aún no hay actividad en el mes.'),
      );
    }

    var maxValor = 1.0;
    for (final d in ultimos7) {
      if (d.ingresos > maxValor) maxValor = d.ingresos;
      if (d.egresos > maxValor) maxValor = d.egresos;
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final dia in ultimos7)
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
                      DateFormat('E').format(dia.fecha).replaceFirst('.', ''),
                      style: Theme.of(context).textTheme.labelSmall,
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

class _MovimientosHeader extends StatelessWidget {
  const _MovimientosHeader({this.onOpenChat});

  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Movimientos Recientes',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (onOpenChat != null)
          TextButton(onPressed: onOpenChat, child: const Text('Ver todos')),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIngreso
                  ? LuminaColors.primary.withValues(alpha: 0.1)
                  : LuminaColors.errorContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIngreso ? Icons.shopping_bag : Icons.shopping_cart,
              size: 20,
              color: isIngreso
                  ? LuminaColors.primary
                  : LuminaColors.onErrorContainer,
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
                Text(
                  DateFormat('d MMM, HH:mm').format(transaccion.fecha),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isIngreso ? '+' : '-'}Q${transaccion.monto.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isIngreso
                  ? LuminaColors.positive
                  : LuminaColors.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LuminaColors.errorContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
      ),
      child: Column(
        children: [
          Text(
            mensaje,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: LuminaColors.onErrorContainer),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({this.onOpenChat});

  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LuminaColors.secondaryContainer,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, size: 32, color: LuminaColors.primary),
          const SizedBox(height: 12),
          Text(
            'Aún no hay movimientos registrados. Habla con el asistente '
            'para registrar tu primera venta o compra.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onOpenChat != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Ir al asistente'),
            ),
          ],
        ],
      ),
    );
  }
}
