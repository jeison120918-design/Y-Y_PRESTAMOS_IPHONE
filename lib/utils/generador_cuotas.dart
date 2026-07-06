import '../models/cuota.dart';

/// Genera el cronograma de cuotas tipo SAN.
/// El monto total ya viene calculado (capital + interes).
/// Las cuotas son fijas (montoTotal / numCuotas).
/// Las fechas de vencimiento se calculan segun la modalidad:
///   - diario:    +1 dia
///   - semanal:   +7 dias
///   - quincenal: +15 dias
///   - mensual:   +1 mes calendario
List<Cuota> generarCuotas({
  required int prestamoId,
  required double montoTotal,
  required int numCuotas,
  required String modalidad,
  required DateTime fechaInicio,
}) {
  // Trabajamos en centavos (enteros) para evitar errores de redondeo
  // de punto flotante y garantizar que la suma de las cuotas sea
  // EXACTAMENTE igual al monto total del prestamo.
  final int totalCentavos = (montoTotal * 100).round();
  final int cuotaCentavosBase = totalCentavos ~/ numCuotas;
  final int centavosRestantes = totalCentavos - (cuotaCentavosBase * numCuotas);

  final List<Cuota> cuotas = [];

  for (int i = 1; i <= numCuotas; i++) {
    DateTime venc;
    switch (modalidad) {
      case 'diario':
        venc = fechaInicio.add(Duration(days: i));
        break;
      case 'semanal':
        venc = fechaInicio.add(Duration(days: i * 7));
        break;
      case 'quincenal':
        venc = fechaInicio.add(Duration(days: i * 15));
        break;
      case 'mensual':
        venc = _agregarMeses(fechaInicio, i);
        break;
      default:
        venc = fechaInicio.add(Duration(days: i));
    }

    // Las ultimas "centavosRestantes" cuotas reciben 1 centavo extra
    // para que la suma total cuadre exactamente con montoTotal.
    int centavosCuota = cuotaCentavosBase;
    if (i > numCuotas - centavosRestantes) {
      centavosCuota += 1;
    }
    final double cuotaMonto = centavosCuota / 100;

    cuotas.add(
      Cuota(
        prestamoId: prestamoId,
        numero: i,
        monto: cuotaMonto,
        fechaVencimiento:
            "${venc.year.toString().padLeft(4, '0')}-${venc.month.toString().padLeft(2, '0')}-${venc.day.toString().padLeft(2, '0')}",
        pagada: 0,
        montoPagado: 0,
        penalidadAplicada: 0,
      ),
    );
  }
  return cuotas;
}

DateTime _agregarMeses(DateTime base, int meses) {
  int anio = base.year;
  int mes = base.month + meses;
  while (mes > 12) {
    mes -= 12;
    anio += 1;
  }
  // Maneja meses con menos dias (ej: 31 enero + 1 mes => 28/29 febrero)
  int dia = base.day;
  int ultimoDiaDelMes = DateTime(anio, mes + 1, 0).day;
  if (dia > ultimoDiaDelMes) dia = ultimoDiaDelMes;
  return DateTime(anio, mes, dia);
}
