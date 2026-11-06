import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/proveedor.dart';
import '../providers/proveedores_provider.dart';
import '../providers/supabase_provider.dart';
import '../services/supabase_repository.dart';
import '../theme/lumina_theme.dart';

class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedoresAsync = ref.watch(proveedoresProvider);

    return Scaffold(
      backgroundColor: LuminaColors.surface,
      appBar: AppBar(
        title: const Text('Directorio de Proveedores'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(proveedoresProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref, proveedor: null),
        backgroundColor: LuminaColors.primary,
        foregroundColor: LuminaColors.onPrimary,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo Proveedor'),
      ),
      body: SafeArea(
        child: proveedoresAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: LuminaColors.negative),
                  const SizedBox(height: 12),
                  Text(
                    'No se pudo cargar la lista de proveedores.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(proveedoresProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          data: (proveedores) {
            if (proveedores.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: LuminaColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          size: 56,
                          color: LuminaColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no tienes proveedores',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registra a las personas y empresas que te surten mercadería para contactarlos rápidamente por llamada o WhatsApp.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: LuminaColors.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _abrirFormulario(context, ref, proveedor: null),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar primer proveedor'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: proveedores.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = proveedores[index];
                return _ProveedorCard(
                  proveedor: p,
                  onEditar: () => _abrirFormulario(context, ref, proveedor: p),
                  onEliminar: () => _confirmarEliminar(context, ref, p),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    WidgetRef ref, {
    required Proveedor? proveedor,
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
      builder: (_) => _ProveedorForm(repo: repo, proveedor: proveedor),
    );

    if (guardado == true) {
      ref.invalidate(proveedoresProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            proveedor == null
                ? 'Proveedor registrado exitosamente.'
                : 'Proveedor actualizado.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    WidgetRef ref,
    Proveedor p,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar proveedor?'),
        content: Text('¿Deseas dar de baja a ${p.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: LuminaColors.negative),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final repo = ref.read(supabaseRepositoryProvider);
      final ok = await repo.eliminarProveedor(p.id);
      if (ok) {
        ref.invalidate(proveedoresProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se eliminó a ${p.nombre}.')),
        );
      }
    }
  }
}

class _ProveedorCard extends StatelessWidget {
  const _ProveedorCard({
    required this.proveedor,
    required this.onEditar,
    required this.onEliminar,
  });

  final Proveedor proveedor;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  Future<void> _llamar(String telefono) async {
    final uri = Uri.parse('tel:${telefono.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsapp(String telefono) async {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$numeroLimpio');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = proveedor;
    final tieneTelefono = p.telefono != null && p.telefono!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: LuminaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        border: Border.all(color: LuminaColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: LuminaColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: LuminaColors.primaryContainer,
                child: Text(
                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: LuminaColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (p.contacto != null && p.contacto!.trim().isNotEmpty)
                      Text(
                        'Contacto: ${p.contacto}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: LuminaColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (val) {
                  if (val == 'editar') onEditar();
                  if (val == 'eliminar') onEliminar();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: LuminaColors.negative),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: LuminaColors.negative)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (p.diasVisita != null && p.diasVisita!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: LuminaColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: LuminaColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Visita: ${p.diasVisita}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: LuminaColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (p.direccion != null && p.direccion!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: LuminaColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.direccion!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LuminaColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (p.notas != null && p.notas!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.notas!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: LuminaColors.onSurfaceVariant,
              ),
            ),
          ],
          if (tieneTelefono) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _llamar(p.telefono!),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text(p.telefono!),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _whatsapp(p.telefono!),
                  tooltip: 'WhatsApp',
                  icon: const Icon(Icons.chat_outlined, color: Colors.green),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProveedorForm extends StatefulWidget {
  const _ProveedorForm({required this.repo, required this.proveedor});

  final FinanzasRepository repo;
  final Proveedor? proveedor;

  @override
  State<_ProveedorForm> createState() => _ProveedorFormState();
}

class _ProveedorFormState extends State<_ProveedorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _contacto;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  late final TextEditingController _diasVisita;
  late final TextEditingController _notas;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedor;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _contacto = TextEditingController(text: p?.contacto ?? '');
    _telefono = TextEditingController(text: p?.telefono ?? '');
    _direccion = TextEditingController(text: p?.direccion ?? '');
    _diasVisita = TextEditingController(text: p?.diasVisita ?? '');
    _notas = TextEditingController(text: p?.notas ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _contacto.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _diasVisita.dispose();
    _notas.dispose();
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
      final contacto = _contacto.text.trim().isEmpty ? null : _contacto.text.trim();
      final telefono = _telefono.text.trim().isEmpty ? null : _telefono.text.trim();
      final direccion = _direccion.text.trim().isEmpty ? null : _direccion.text.trim();
      final diasVisita = _diasVisita.text.trim().isEmpty ? null : _diasVisita.text.trim();
      final notas = _notas.text.trim().isEmpty ? null : _notas.text.trim();

      if (widget.proveedor == null) {
        final nuevo = await widget.repo.crearProveedor(
          nombre: nombre,
          contacto: contacto,
          telefono: telefono,
          direccion: direccion,
          diasVisita: diasVisita,
          notas: notas,
        );
        if (nuevo == null) {
          setState(() {
            _error = 'No se pudo crear el proveedor.';
            _guardando = false;
          });
          return;
        }
      } else {
        final prov = Proveedor(
          id: widget.proveedor!.id,
          nombre: nombre,
          contacto: contacto,
          telefono: telefono,
          direccion: direccion,
          diasVisita: diasVisita,
          notas: notas,
          activo: widget.proveedor!.activo,
        );
        final ok = await widget.repo.actualizarProveedor(prov);
        if (!ok) {
          setState(() {
            _error = 'No se pudo actualizar el proveedor.';
            _guardando = false;
          });
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Error al guardar: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.proveedor == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
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
                      esNuevo ? 'Nuevo Proveedor' : 'Editar Proveedor',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: LuminaColors.negative)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Empresa o Nombre del Proveedor *',
                  hintText: 'Ej. Distribuidora Los Altos, Don Pedro',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del proveedor' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contacto,
                      decoration: const InputDecoration(
                        labelText: 'Persona de contacto',
                        hintText: 'Ej. Vendedor Carlos',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono / WhatsApp',
                        hintText: 'Ej. 55554444',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _diasVisita,
                decoration: const InputDecoration(
                  labelText: 'Días de visita o reparto',
                  hintText: 'Ej. Martes y Viernes por la mañana',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccion,
                decoration: const InputDecoration(
                  labelText: 'Dirección o Ubicación',
                  hintText: 'Ej. Zona 3, Mercado Central',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notas,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas comerciales',
                  hintText: 'Ej. Pide pedido con 2 días de anticipación, da crédito.',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando...' : 'Guardar Proveedor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
