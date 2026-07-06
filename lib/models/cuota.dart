class Cuota {
  int? id;
  int prestamoId;
  int numero;
  double monto;
  String fechaVencimiento; // ISO yyyy-MM-dd
  int pagada; // 0 / 1
  double montoPagado;
  String? fechaPago;
  double penalidadAplicada;

  Cuota({
    this.id,
    required this.prestamoId,
    required this.numero,
    required this.monto,
    required this.fechaVencimiento,
    required this.pagada,
    required this.montoPagado,
    this.fechaPago,
    required this.penalidadAplicada,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamo_id': prestamoId,
      'numero': numero,
      'monto': monto,
      'fecha_vencimiento': fechaVencimiento,
      'pagada': pagada,
      'monto_pagado': montoPagado,
      'fecha_pago': fechaPago,
      'penalidad_aplicada': penalidadAplicada,
    };
  }

  factory Cuota.fromMap(Map<String, dynamic> map) {
    return Cuota(
      id: map['id'],
      prestamoId: map['prestamo_id'] ?? 0,
      numero: map['numero'] ?? 0,
      monto: (map['monto'] ?? 0).toDouble(),
      fechaVencimiento: map['fecha_vencimiento'] ?? '',
      pagada: map['pagada'] ?? 0,
      montoPagado: (map['monto_pagado'] ?? 0).toDouble(),
      fechaPago: map['fecha_pago'],
      penalidadAplicada: (map['penalidad_aplicada'] ?? 0).toDouble(),
    );
  }

  DateTime get fechaVencimientoDT => DateTime.parse(fechaVencimiento);
  bool get estaPagada => pagada == 1;
}
