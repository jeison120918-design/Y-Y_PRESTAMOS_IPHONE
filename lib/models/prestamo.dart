class Prestamo {
  int? id;
  int clienteId;
  double capital;
  double tasaInteres;
  double montoTotal;
  String modalidad; // 'diario', 'semanal', 'quincenal', 'mensual'
  int numCuotas;
  String fechaInicio;
  double montoPenalidad;
  String estado; // 'activo', 'pagado', 'mora'

  Prestamo({
    this.id,
    required this.clienteId,
    required this.capital,
    required this.tasaInteres,
    required this.montoTotal,
    required this.modalidad,
    required this.numCuotas,
    required this.fechaInicio,
    required this.montoPenalidad,
    required this.estado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'capital': capital,
      'tasa_interes': tasaInteres,
      'monto_total': montoTotal,
      'modalidad': modalidad,
      'num_cuotas': numCuotas,
      'fecha_inicio': fechaInicio,
      'monto_penalidad': montoPenalidad,
      'estado': estado,
    };
  }

  factory Prestamo.fromMap(Map<String, dynamic> map) {
    return Prestamo(
      id: map['id'],
      clienteId: map['cliente_id'] ?? 0,
      capital: (map['capital'] ?? 0).toDouble(),
      tasaInteres: (map['tasa_interes'] ?? 0).toDouble(),
      montoTotal: (map['monto_total'] ?? 0).toDouble(),
      modalidad: map['modalidad'] ?? 'diario',
      numCuotas: map['num_cuotas'] ?? 0,
      fechaInicio: map['fecha_inicio'] ?? '',
      montoPenalidad: (map['monto_penalidad'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'activo',
    );
  }
}
