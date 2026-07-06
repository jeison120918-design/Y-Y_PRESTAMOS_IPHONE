import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/prestamo.dart';
import '../models/cliente.dart';
import '../models/cuota.dart';
import '../models/pago.dart';
import '../models/prestamista.dart';
import '../utils/formato.dart';
import '../utils/calculadora_penalidad.dart';
import '../main.dart';

/// Carga el logo Y&Y desde los assets. Se usa en el encabezado de todos los
/// documentos PDF generados (recibo de pago y detalle de prestamo).
/// Devuelve null si el asset no esta disponible.
Future<pw.MemoryImage?> _cargarLogoYY() async {
  try {
    final data = await rootBundle.load(AndryPrestamosApp.logoAsset);
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

/// Genera un PDF tipo ticket (ancho de papel termico ~58mm o 80mm) para el
/// RECIBO DE PAGO. Sirve para compartir por WhatsApp/correo o imprimir
/// usando el dialogo del sistema (`Printing.layoutPdf`).
///
/// Ancho configurable: 58 (por defecto) u 80 milimetros.
Future<Uint8List> generarReciboPagoPdf({
  required Prestamista? prestamista,
  required Cliente cliente,
  required Prestamo prestamo,
  required Cuota cuota,
  required Pago pago,
  required double saldoPendiente,
  double anchoMm = 58,
}) async {
  final pdf = pw.Document();
  final logo = await _cargarLogoYY();

  final nombreNegocio = (prestamista?.nombre.trim().isNotEmpty == true)
      ? prestamista!.nombre
      : AndryPrestamosApp.nombreNegocio;
  final telNegocio = (prestamista?.telefono.trim().isNotEmpty == true)
      ? prestamista!.telefono
      : AndryPrestamosApp.telefonoDueno;

  // Ancho similar a una tira termica de 58mm u 80mm.
  final formato = PdfPageFormat(anchoMm * PdfPageFormat.mm, double.infinity,
      marginAll: 4 * PdfPageFormat.mm);

  pdf.addPage(pw.Page(
    pageFormat: formato,
    build: (ctx) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (logo != null)
            pw.Center(
              child: pw.Container(
                height: 40,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ),
          if (logo != null) pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              nombreNegocio.toUpperCase(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Center(
            child: pw.Text('Tel: $telNegocio',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          if (prestamista?.direccion.trim().isNotEmpty == true)
            pw.Center(
              child: pw.Text(prestamista!.direccion,
                  style: const pw.TextStyle(fontSize: 7)),
            ),
          pw.Divider(height: 4),
          pw.Center(
            child: pw.Text('RECIBO DE PAGO',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Divider(height: 4),
          _filaPdf('Recibo:', '#${pago.id ?? '-'}'),
          _filaPdf('Fecha:', formatoFechaStr(pago.fecha)),
          pw.SizedBox(height: 4),
          pw.Text('CLIENTE',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text(cliente.nombre, style: const pw.TextStyle(fontSize: 8)),
          if (cliente.cedula.trim().isNotEmpty)
            pw.Text('Ced: ${cliente.cedula}',
                style: const pw.TextStyle(fontSize: 7)),
          if (cliente.telefono.trim().isNotEmpty)
            pw.Text('Tel: ${cliente.telefono}',
                style: const pw.TextStyle(fontSize: 7)),
          pw.SizedBox(height: 4),
          _filaPdf('Prestamo:', '#${prestamo.id}'),
          _filaPdf('Cuota:', '#${cuota.numero} / ${prestamo.numCuotas}'),
          _filaPdf('Modalidad:', modalidadLabel(prestamo.modalidad)),
          _filaPdf('Vence:', formatoFechaStr(cuota.fechaVencimiento)),
          pw.Divider(height: 4),
          pw.Text('DETALLE DEL PAGO',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          _filaPdf('Capital cuota', formatoMoneda(pago.monto)),
          if (pago.penalidad > 0)
            _filaPdf('Mora/Penalidad', formatoMoneda(pago.penalidad)),
          pw.Divider(height: 4),
          _filaPdf('TOTAL PAGADO', formatoMoneda(pago.monto + pago.penalidad),
              bold: true, size: 10),
          pw.SizedBox(height: 4),
          _filaPdf('Estado cuota:', cuota.estaPagada ? 'PAGADA' : 'PARCIAL'),
          _filaPdf('Saldo prestamo:', formatoMoneda(saldoPendiente),
              bold: true),
          if (pago.observaciones.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Obs: ${pago.observaciones}',
                style: const pw.TextStyle(fontSize: 7)),
          ],
          pw.Divider(height: 4),
          pw.Center(
            child: pw.Text('Gracias por su pago',
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('--------------------------------',
                style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.Center(
            child: pw.Text('Sistema desarrollado por',
                style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.Center(
            child: pw.Text(AndryPrestamosApp.creadorSistema,
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Center(
            child: pw.Text('Tel: ${AndryPrestamosApp.creadorTelefono}',
                style: const pw.TextStyle(fontSize: 7)),
          ),
        ],
      );
    },
  ));

  return pdf.save();
}

/// Genera un PDF con el DETALLE COMPLETO del prestamo + cronograma.
/// Ancho configurable: 58 (por defecto) u 80 milimetros.
Future<Uint8List> generarDetallePrestamoPdf({
  required Prestamista? prestamista,
  required Cliente cliente,
  required Prestamo prestamo,
  required List<Cuota> cuotas,
  required double totalCobrado,
  required double saldoPendiente,
  required double moraVigente,
  double anchoMm = 58,
}) async {
  final pdf = pw.Document();
  final logo = await _cargarLogoYY();

  final nombreNegocio = (prestamista?.nombre.trim().isNotEmpty == true)
      ? prestamista!.nombre
      : AndryPrestamosApp.nombreNegocio;
  final telNegocio = (prestamista?.telefono.trim().isNotEmpty == true)
      ? prestamista!.telefono
      : AndryPrestamosApp.telefonoDueno;

  final formato = PdfPageFormat(anchoMm * PdfPageFormat.mm, double.infinity,
      marginAll: 4 * PdfPageFormat.mm);

  pdf.addPage(pw.Page(
    pageFormat: formato,
    build: (ctx) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (logo != null)
            pw.Center(
              child: pw.Container(
                height: 40,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ),
          if (logo != null) pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              nombreNegocio.toUpperCase(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Center(
            child: pw.Text('Tel: $telNegocio',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Divider(height: 4),
          pw.Center(
            child: pw.Text('DETALLE DE PRESTAMO',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Center(
            child: pw.Text('#${prestamo.id}',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Divider(height: 4),
          pw.Text('CLIENTE',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text(cliente.nombre, style: const pw.TextStyle(fontSize: 8)),
          if (cliente.cedula.trim().isNotEmpty)
            pw.Text('Ced: ${cliente.cedula}',
                style: const pw.TextStyle(fontSize: 7)),
          if (cliente.telefono.trim().isNotEmpty)
            pw.Text('Tel: ${cliente.telefono}',
                style: const pw.TextStyle(fontSize: 7)),
          if (cliente.direccion.trim().isNotEmpty)
            pw.Text('Dir: ${cliente.direccion}',
                style: const pw.TextStyle(fontSize: 7)),
          pw.SizedBox(height: 4),
          pw.Text('DATOS DEL PRESTAMO',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          _filaPdf('Capital', formatoMoneda(prestamo.capital)),
          _filaPdf('Interes', '${prestamo.tasaInteres.toStringAsFixed(2)}%'),
          _filaPdf('Monto total', formatoMoneda(prestamo.montoTotal)),
          _filaPdf('Modalidad', modalidadLabel(prestamo.modalidad)),
          _filaPdf('No. cuotas', '${prestamo.numCuotas}'),
          _filaPdf('Inicio', formatoFechaStr(prestamo.fechaInicio)),
          _filaPdf(
              'Penal./dia',
              formatoMoneda(penalidadPorDia(
                  prestamo.modalidad, prestamo.montoPenalidad))),
          pw.Divider(height: 4),
          pw.Text('CRONOGRAMA',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('#',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('Vence',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('Monto',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('Est.',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          ...cuotas.map((c) {
            String estado;
            if (c.estaPagada) {
              estado = 'PAG';
            } else if (estaEnMora(c)) {
              estado = 'MOR';
            } else {
              estado = 'PEN';
            }
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${c.numero}', style: const pw.TextStyle(fontSize: 7)),
                pw.Text(formatoFechaStr(c.fechaVencimiento),
                    style: const pw.TextStyle(fontSize: 7)),
                pw.Text(formatoMoneda(c.monto).replaceAll('RD\$ ', ''),
                    style: const pw.TextStyle(fontSize: 7)),
                pw.Text(estado, style: const pw.TextStyle(fontSize: 7)),
              ],
            );
          }),
          pw.Divider(height: 4),
          _filaPdf('Total cobrado', formatoMoneda(totalCobrado), bold: true),
          _filaPdf('Saldo', formatoMoneda(saldoPendiente), bold: true),
          _filaPdf('Mora vigente', formatoMoneda(moraVigente), bold: true),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('_______________________',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Center(
            child: pw.Text('Firma del cliente',
                style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text('_______________________',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Center(
            child:
                pw.Text('Prestamista', style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('--------------------------------',
                style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.Center(
            child: pw.Text('Sistema desarrollado por',
                style: const pw.TextStyle(fontSize: 7)),
          ),
          pw.Center(
            child: pw.Text(AndryPrestamosApp.creadorSistema,
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Center(
            child: pw.Text('Tel: ${AndryPrestamosApp.creadorTelefono}',
                style: const pw.TextStyle(fontSize: 7)),
          ),
        ],
      );
    },
  ));

  return pdf.save();
}

pw.Widget _filaPdf(String k, String v, {bool bold = false, double size = 8}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k,
          style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(v,
          style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ],
  );
}

/// Genera el TEXTO plano del recibo (para compartir por WhatsApp/SMS).
String generarReciboPagoTexto({
  required Prestamista? prestamista,
  required Cliente cliente,
  required Prestamo prestamo,
  required Cuota cuota,
  required Pago pago,
  required double saldoPendiente,
}) {
  final nombreNegocio = (prestamista?.nombre.trim().isNotEmpty == true)
      ? prestamista!.nombre
      : AndryPrestamosApp.nombreNegocio;
  final telNegocio = (prestamista?.telefono.trim().isNotEmpty == true)
      ? prestamista!.telefono
      : AndryPrestamosApp.telefonoDueno;

  final b = StringBuffer();
  b.writeln('================================');
  b.writeln('   ${nombreNegocio.toUpperCase()}');
  b.writeln('   Tel: $telNegocio');
  b.writeln('================================');
  b.writeln('         RECIBO DE PAGO');
  b.writeln('--------------------------------');
  b.writeln('Recibo: #${pago.id ?? '-'}');
  b.writeln('Fecha:  ${formatoFechaStr(pago.fecha)}');
  b.writeln('--------------------------------');
  b.writeln('Cliente: ${cliente.nombre}');
  if (cliente.cedula.trim().isNotEmpty) {
    b.writeln('Cedula:  ${cliente.cedula}');
  }
  if (cliente.telefono.trim().isNotEmpty) {
    b.writeln('Tel:     ${cliente.telefono}');
  }
  b.writeln('--------------------------------');
  b.writeln('Prestamo:  #${prestamo.id}');
  b.writeln('Cuota:     #${cuota.numero} / ${prestamo.numCuotas}');
  b.writeln('Modalidad: ${modalidadLabel(prestamo.modalidad)}');
  b.writeln('Vence:     ${formatoFechaStr(cuota.fechaVencimiento)}');
  b.writeln('--------------------------------');
  b.writeln('Capital cuota:  ${formatoMoneda(pago.monto)}');
  if (pago.penalidad > 0) {
    b.writeln('Mora/Penalidad: ${formatoMoneda(pago.penalidad)}');
  }
  b.writeln('*TOTAL PAGADO:  ${formatoMoneda(pago.monto + pago.penalidad)}*');
  b.writeln('--------------------------------');
  b.writeln('Estado cuota:   ${cuota.estaPagada ? "PAGADA" : "PARCIAL"}');
  b.writeln('Saldo prestamo: ${formatoMoneda(saldoPendiente)}');
  if (pago.observaciones.trim().isNotEmpty) {
    b.writeln('--------------------------------');
    b.writeln('Obs: ${pago.observaciones}');
  }
  b.writeln('================================');
  b.writeln('     Gracias por su pago');
  b.writeln('================================');
  b.writeln('');
  b.writeln('Sistema desarrollado por');
  b.writeln('${AndryPrestamosApp.creadorSistema}');
  b.writeln('Tel: ${AndryPrestamosApp.creadorTelefono}');
  return b.toString();
}
