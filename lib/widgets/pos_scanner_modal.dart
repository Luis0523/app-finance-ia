import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/producto_inventario.dart';
import '../providers/pos_provider.dart';
import '../theme/lumina_theme.dart';

class PosScannerModal extends ConsumerStatefulWidget {
  const PosScannerModal({
    super.key,
    required this.catalogo,
  });

  final List<ProductoInventario> catalogo;

  static Future<void> abrir(
    BuildContext context, {
    required List<ProductoInventario> catalogo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosScannerModal(catalogo: catalogo),
    );
  }

  @override
  ConsumerState<PosScannerModal> createState() => _PosScannerModalState();
}

class _PosScannerModalState extends ConsumerState<PosScannerModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  String? _ultimoCodigo;
  DateTime? _ultimoMomentoEscaneo;

  String? _mensajeBanner;
  bool _bannerExito = true;
  Timer? _timerBanner;

  @override
  void dispose() {
    _timerBanner?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final ahora = DateTime.now();
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;

      // Anti-rebote para el mismo código en menos de 1.2 segundos
      if (_ultimoCodigo == code &&
          _ultimoMomentoEscaneo != null &&
          ahora.difference(_ultimoMomentoEscaneo!).inMilliseconds < 1200) {
        continue;
      }

      _ultimoCodigo = code;
      _ultimoMomentoEscaneo = ahora;

      final prod = ref.read(posProvider.notifier).agregarPorCodigoBarras(
            code,
            widget.catalogo,
          );

      if (prod != null) {
        HapticFeedback.mediumImpact();
        _mostrarNotificacion(
          'Agregado: ${prod.nombre} (Q${prod.precioVenta.toStringAsFixed(2)})',
          exito: true,
        );
      } else {
        HapticFeedback.heavyImpact();
        _mostrarNotificacion(
          'Código no registrado: $code',
          exito: false,
        );
      }
      break;
    }
  }

  void _mostrarNotificacion(String mensaje, {required bool exito}) {
    _timerBanner?.cancel();
    setState(() {
      _mensajeBanner = mensaje;
      _bannerExito = exito;
    });
    _timerBanner = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _mensajeBanner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(posProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(LuminaRadii.card)),
        child: Stack(
          children: [
            // Cámara
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

            // Visor central
            Center(
              child: Container(
                width: 270,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _mensajeBanner != null
                        ? (_bannerExito ? LuminaColors.positive : LuminaColors.negative)
                        : LuminaColors.primary,
                    width: 2.8,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Barra Superior
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Escaneo Rápido Continuo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${carrito.totalArticulos} artículos • Q${carrito.totalVenta.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: LuminaColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                      onPressed: () => _controller.toggleTorch(),
                      tooltip: 'Linterna',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
            ),

            // Banner dinámico de retroalimentación
            if (_mensajeBanner != null)
              Positioned(
                top: 86,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bannerExito
                          ? LuminaColors.positive.withValues(alpha: 0.92)
                          : LuminaColors.negative.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _bannerExito ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _mensajeBanner!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Botón inferior para finalizar o ver carrito
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LuminaColors.primary,
                  foregroundColor: LuminaColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  carrito.estaVacio
                      ? 'Listo / Volver al POS'
                      : 'Ver Ticket (${carrito.totalArticulos} arts. • Q${carrito.totalVenta.toStringAsFixed(2)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
