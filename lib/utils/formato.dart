import 'package:intl/intl.dart';

final _formatoMoneda = NumberFormat.currency(
  locale: 'es_DO',
  symbol: 'RD\$ ',
  decimalDigits: 2,
);

String formatoMoneda(double valor) => _formatoMoneda.format(valor);

String formatoFecha(DateTime fecha) =>
    DateFormat('dd/MM/yyyy', 'es').format(fecha);

String formatoFechaStr(String iso) {
  if (iso.isEmpty) return '';
  try {
    return formatoFecha(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String modalidadLabel(String m) {
  switch (m) {
    case 'diario':
      return 'Diario';
    case 'semanal':
      return 'Semanal';
    case 'quincenal':
      return 'Quincenal';
    case 'mensual':
      return 'Mensual';
    default:
      return m;
  }
}
