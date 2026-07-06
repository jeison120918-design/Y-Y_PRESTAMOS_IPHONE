class Prestamista {
  int? id;
  String nombre;
  String cedula;
  String telefono;
  String direccion;
  double capitalInicial;
  String fechaRegistro;

  Prestamista({
    this.id,
    required this.nombre,
    required this.cedula,
    required this.telefono,
    required this.direccion,
    required this.capitalInicial,
    required this.fechaRegistro,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'direccion': direccion,
      'capital_inicial': capitalInicial,
      'fecha_registro': fechaRegistro,
    };
  }

  factory Prestamista.fromMap(Map<String, dynamic> map) {
    return Prestamista(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      cedula: map['cedula'] ?? '',
      telefono: map['telefono'] ?? '',
      direccion: map['direccion'] ?? '',
      capitalInicial: (map['capital_inicial'] ?? 0).toDouble(),
      fechaRegistro: map['fecha_registro'] ?? '',
    );
  }
}
