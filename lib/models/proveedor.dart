class Proveedor {
  const Proveedor({
    required this.id,
    required this.nombre,
    this.contacto,
    this.telefono,
    this.direccion,
    this.diasVisita,
    this.notas,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String? contacto;
  final String? telefono;
  final String? direccion;
  final String? diasVisita;
  final String? notas;
  final bool activo;

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      contacto: json['contacto']?.toString(),
      telefono: json['telefono']?.toString(),
      direccion: json['direccion']?.toString(),
      diasVisita: json['dias_visita']?.toString(),
      notas: json['notas']?.toString(),
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'contacto': contacto,
      'telefono': telefono,
      'direccion': direccion,
      'dias_visita': diasVisita,
      'notas': notas,
      'activo': activo,
    };
  }
}
