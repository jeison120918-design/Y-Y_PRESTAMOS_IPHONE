class Pago {
  int? id;
  int cuotaId;
  double monto;
  double penalidad;
  String fecha;
  String observaciones;

  Pago({
    this.id,
    required this.cuotaId,
    required this.monto,
    required this.penalidad,
    required this.fecha,
    required this.observaciones,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cuota_id': cuotaId,
      'monto': monto,
      'penalidad': penalidad,
      'fecha': fecha,
      'observaciones': observaciones,
    };
  }

  factory Pago.fromMap(Map<String, dynamic> map) {
    return Pago(
      id: map['id'],
      cuotaId: map['cuota_id'] ?? 0,
      monto: (map['monto'] ?? 0).toDouble(),
      penalidad: (map['penalidad'] ?? 0).toDouble(),
      fecha: map['fecha'] ?? '',
      observaciones: map['observaciones'] ?? '',
    );
  }
}
