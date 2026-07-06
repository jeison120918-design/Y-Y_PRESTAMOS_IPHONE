class Cliente {
  int? id;
  int prestamistaId;
  String nombre;
  String cedula;
  String telefono;
  String direccion;
  String referencia;
  String fechaRegistro;

  Cliente({
    this.id,
    required this.prestamistaId,
    required this.nombre,
    required this.cedula,
    required this.telefono,
    required this.direccion,
    required this.referencia,
    required this.fechaRegistro,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamista_id': prestamistaId,
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'direccion': direccion,
      'referencia': referencia,
      'fecha_registro': fechaRegistro,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      prestamistaId: map['prestamista_id'] ?? 0,
      nombre: map['nombre'] ?? '',
      cedula: map['cedula'] ?? '',
      telefono: map['telefono'] ?? '',
      direccion: map['direccion'] ?? '',
      referencia: map['referencia'] ?? '',
      fechaRegistro: map['fecha_registro'] ?? '',
    );
  }
}
