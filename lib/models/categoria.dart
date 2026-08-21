class Categoria {
  const Categoria({required this.id, required this.nombre, required this.tipo});

  final String id;
  final String nombre;
  final String tipo;

  factory Categoria.fromMap(Map<String, dynamic> map) => Categoria(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        tipo: map['tipo'] as String,
      );
}
