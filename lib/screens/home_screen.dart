import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flujo_caja.dart';
import '../models/listado_transaccion.dart';
import '../models/producto_inventario.dart';
import '../models/sugerencia_pedido_proveedor.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/negocio_provider.dart';
import '../providers/supabase_provider.dart';
import '../services/supabase_repository.dart';
import '../theme/lumina_theme.dart';
import 'charts_screen.dart';
import 'cuaderno_fiados_screen.dart';

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
            _Header(nombre: negocio.valueOrNull ?? 'Mi negocio'),
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
              _AlertaStockBajoCard(
                productosBajos: dashboard.value!.inventario
                    .where((p) => p.estado == 'bajo' || p.estado == 'agotado')
                    .toList(),
              ),
              _AlertaProveedoresCard(repo: repo),
              const SizedBox(height: 8),
              const _AccesoCuadernoFiadosCard(),
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

class _Header extends ConsumerWidget {
  const _Header({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(usuarioActualProvider)?.email ?? '';
    final inicial = nombre.trim().isEmpty
        ? 'L'
        : nombre.trim().substring(0, 1).toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Cuenta',
          offset: const Offset(0, 48),
          onSelected: (valor) async {
            if (valor == 'salir') {
              await ref.read(authServiceProvider).cerrarSesion();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(email.isEmpty ? 'Mi cuenta' : email),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'salir',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('Cerrar sesión'),
                ],
              ),
            ),
          ],
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LuminaColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              inicial,
              style: const TextStyle(
                color: LuminaColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
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

class _AlertaStockBajoCard extends StatelessWidget {
  const _AlertaStockBajoCard({required this.productosBajos});

  final List<ProductoInventario> productosBajos;

  @override
  Widget build(BuildContext context) {
    if (productosBajos.isEmpty) return const SizedBox.shrink();

    final nombres = productosBajos.map((p) => p.nombre).take(3).join(', ');
    final resto =
        productosBajos.length > 3 ? ' y ${productosBajos.length - 3} más' : '';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber.shade900,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${productosBajos.length} ${productosBajos.length == 1 ? "producto por agotarse" : "productos por agotarse"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$nombres$resto',
                  style: TextStyle(
                    color: Colors.brown.shade800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertaProveedoresCard extends StatelessWidget {
  const _AlertaProveedoresCard({required this.repo});
  final FinanzasRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SugerenciaPedidoProveedor>>(
      future: repo.obtenerSugerenciasPedidosProveedores(),
      builder: (context, snapshot) {
        final sugerencias = snapshot.data ?? [];
        if (sugerencias.isEmpty) return const SizedBox.shrink();

        final urgentes =
            sugerencias.where((s) => s.esVisitaHoy || s.esVisitaManana).toList();
        final primero = urgentes.isNotEmpty ? urgentes.first : sugerencias.first;

        final aviso = primero.esVisitaHoy
            ? '¡Visita HOY!'
            : primero.esVisitaManana
                ? 'Visita MAÑANA'
                : 'Próxima visita';

        return InkWell(
          borderRadius: BorderRadius.circular(LuminaRadii.card),
          onTap: () => _mostrarModalSugerencias(context, sugerencias),
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LuminaColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(LuminaRadii.card),
              border: Border.all(
                color: primero.esVisitaHoy
                    ? Colors.red.shade300
                    : LuminaColors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LuminaColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: LuminaColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pedidos a Proveedores ($aviso)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'Q${primero.costoTotalEstimado.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${primero.proveedor.nombre}: ${primero.totalArticulos} productos sugeridos. Toca para ver detalle.',
                        style: TextStyle(
                          color: LuminaColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarModalSugerencias(
    BuildContext context,
    List<SugerenciaPedidoProveedor> sugerencias,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping, color: LuminaColors.primary),
                  const SizedBox(width: 8),
                  Text('Sugerencias de Pedidos', style: LuminaTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sugerencias.length,
                  itemBuilder: (ctx, i) {
                    final sug = sugerencias[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: LuminaColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                sug.proveedor.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Q${sug.costoTotalEstimado.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            'Visita: ${sug.diaVisitaTexto}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const Divider(height: 16),
                          ...sug.productos.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.producto.nombre} (Stock: ${item.existenciasActuales.toStringAsFixed(0)})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Pedir ${item.cantidadSugerida.toStringAsFixed(0)} ${item.producto.unidadMedida}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: LuminaColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccesoCuadernoFiadosCard extends StatelessWidget {
  const _AccesoCuadernoFiadosCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LuminaRadii.card),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CuadernoFiadosScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(LuminaRadii.card),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book,
                color: Colors.amber.shade900,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cuaderno de Fiados (Cuentas por Cobrar)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    'Gestiona las deudas de clientes, días de atraso y cobros',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
