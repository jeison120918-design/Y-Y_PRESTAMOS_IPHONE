import '../models/cuota.dart';

/// Calcula la penalidad acumulada de una cuota basada en REDITOS DIARIOS.
///
/// Logica nueva (v2):
/// - Si la cuota ya esta pagada, retorna 0.
/// - Si aun no ha vencido, retorna 0.
/// - La penalidad se aplica de forma PRORRATEADA por DIA, no por periodos
///   completos. Es decir, cada dia vencido acumula la fraccion correspondiente:
///
///     diario:    penalidad = montoPenalidad * diasVencidos
///     semanal:   penalidad = (montoPenalidad / 7)  * diasVencidos
///     quincenal: penalidad = (montoPenalidad / 15) * diasVencidos
///     mensual:   penalidad = (montoPenalidad / 30) * diasVencidos
///
/// De este modo el monto crece dia a dia y, si el cliente paga antes de
/// completar el periodo, solo se le cobra la fraccion correspondiente.
///
/// La penalidad NO se persiste; se recalcula en tiempo real. Al registrar el
/// pago, se "congela" copiandose a la columna `penalidad_aplicada`.
double calcularPenalidad(
  Cuota cuota,
  String modalidad,
  double montoPenalidad, {
  DateTime? referencia,
}) {
  if (cuota.estaPagada) return 0;
  if (montoPenalidad <= 0) return 0;

  final hoy = referencia ?? DateTime.now();
  final vence = cuota.fechaVencimientoDT;

  final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final venceSoloFecha = DateTime(vence.year, vence.month, vence.day);

  if (!hoySoloFecha.isAfter(venceSoloFecha)) return 0;

  final diasVencidos = hoySoloFecha.difference(venceSoloFecha).inDays;
  if (diasVencidos <= 0) return 0;

  double penalidadDiaria;
  switch (modalidad) {
    case 'diario':
      penalidadDiaria = montoPenalidad;
      break;
    case 'semanal':
      penalidadDiaria = montoPenalidad / 7.0;
      break;
    case 'quincenal':
      penalidadDiaria = montoPenalidad / 15.0;
      break;
    case 'mensual':
      penalidadDiaria = montoPenalidad / 30.0;
      break;
    default:
      penalidadDiaria = montoPenalidad;
  }

  final total = penalidadDiaria * diasVencidos;
  // Redondeo a 2 decimales
  return double.parse(total.toStringAsFixed(2));
}

/// Penalidad diaria (por dia de retraso) segun la modalidad.
double penalidadPorDia(String modalidad, double montoPenalidad) {
  switch (modalidad) {
    case 'diario':
      return montoPenalidad;
    case 'semanal':
      return montoPenalidad / 7.0;
    case 'quincenal':
      return montoPenalidad / 15.0;
    case 'mensual':
      return montoPenalidad / 30.0;
    default:
      return montoPenalidad;
  }
}

/// Devuelve true si la cuota esta en mora (vencida y no pagada).
bool estaEnMora(Cuota cuota, {DateTime? referencia}) {
  if (cuota.estaPagada) return false;
  final hoy = referencia ?? DateTime.now();
  final vence = cuota.fechaVencimientoDT;
  final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final venceSoloFecha = DateTime(vence.year, vence.month, vence.day);
  return hoySoloFecha.isAfter(venceSoloFecha);
}

/// Dias de retraso (>= 0). Si aun no vence, retorna 0.
int diasDeRetraso(Cuota cuota, {DateTime? referencia}) {
  final hoy = referencia ?? DateTime.now();
  final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final venceSoloFecha = DateTime(
    cuota.fechaVencimientoDT.year,
    cuota.fechaVencimientoDT.month,
    cuota.fechaVencimientoDT.day,
  );
  final diff = hoySoloFecha.difference(venceSoloFecha).inDays;
  return diff < 0 ? 0 : diff;
}

/// Dias para que venza una cuota (positivo: faltan, negativo: ya vencio).
int diasParaVencer(Cuota cuota, {DateTime? referencia}) {
  final hoy = referencia ?? DateTime.now();
  final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final venceSoloFecha = DateTime(
    cuota.fechaVencimientoDT.year,
    cuota.fechaVencimientoDT.month,
    cuota.fechaVencimientoDT.day,
  );
  return venceSoloFecha.difference(hoySoloFecha).inDays;
}
