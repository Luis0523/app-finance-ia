import 'package:flutter/material.dart';

import '../theme/lumina_theme.dart';
import 'chat_screen.dart';
import 'historial_screen.dart';
import 'home_screen.dart';
import 'stock_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _indice = 0;

  void _irA(int indice) {
    setState(() => _indice = indice);
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      HomeScreen(onOpenChat: () => _irA(1)),
      const ChatScreen(),
      const HistorialScreen(),
      const StockScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _indice, children: paginas),
      bottomNavigationBar: _BottomNav(indice: _indice, onSelected: _irA),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.indice, required this.onSelected});

  final int indice;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LuminaColors.surface.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: LuminaColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _NavItem(
                icono: Icons.dashboard_outlined,
                iconoActivo: Icons.dashboard,
                etiqueta: 'Inicio',
                activo: indice == 0,
                onTap: () => onSelected(0),
              ),
              const Expanded(child: SizedBox.shrink()),
              GestureDetector(
                onTap: () => onSelected(1),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: LuminaColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LuminaColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: LuminaColors.onPrimary,
                    size: 28,
                  ),
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
              _NavItem(
                icono: Icons.account_balance_wallet_outlined,
                iconoActivo: Icons.account_balance_wallet,
                etiqueta: 'Historial',
                activo: indice == 2,
                onTap: () => onSelected(2),
              ),
              _NavItem(
                icono: Icons.inventory_2_outlined,
                iconoActivo: Icons.inventory_2,
                etiqueta: 'Stock',
                activo: indice == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activo ? LuminaColors.primary : LuminaColors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuminaRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(activo ? iconoActivo : icono, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              etiqueta.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
