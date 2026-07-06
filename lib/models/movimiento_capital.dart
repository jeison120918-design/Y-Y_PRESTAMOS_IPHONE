class MovimientoCapital {
  int? id;
  String tipo; // 'inyeccion', 'retiro', 'prestamo_otorgado', 'pago_recibido'
  double monto;
  String? descripcion;
  String fecha;
  int? referenciaId;

  MovimientoCapital({
    this.id,
    required this.tipo,
    required this.monto,
    this.descripcion,
    required this.fecha,
    this.referenciaId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo,
        'monto': monto,
        'descripcion': descripcion,
        'fecha': fecha,
        'referencia_id': referenciaId,
      };

  factory MovimientoCapital.fromMap(Map<String, dynamic> m) =>
      MovimientoCapital(
        id: m['id'],
        tipo: m['tipo'] ?? '',
        monto: (m['monto'] ?? 0).toDouble(),
        descripcion: m['descripcion'],
        fecha: m['fecha'] ?? '',
        referenciaId: m['referencia_id'],
      );

  bool get esEntrada => tipo == 'inyeccion' || tipo == 'pago_recibido';

  String get tipoLabel {
    switch (tipo) {
      case 'inyeccion':
        return 'Inyección de Capital';
      case 'retiro':
        return 'Retiro de Capital';
      case 'prestamo_otorgado':
        return 'Préstamo Otorgado';
      case 'pago_recibido':
        return 'Pago Recibido';
      default:
        return tipo;
    }
  }
}
