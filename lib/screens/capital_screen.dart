import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/db_helper.dart';
import '../models/movimiento_capital.dart';
import '../main.dart';

class CapitalScreen extends StatefulWidget {
  final bool mostrarEstado;
  const CapitalScreen({super.key, this.mostrarEstado = false});

  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<MovimientoCapital> _movimientos = [];
  double _capitalActual = 0;
  double _capitalEnPrestamos = 0;
  double _totalCobrado = 0;
  double _totalPendiente = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _cargar().then((_) {
      if (widget.mostrarEstado) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tab.animateTo(1);
        });
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    _movimientos = await DBHelper().getMovimientosCapital();
    _capitalActual = await DBHelper().getCapitalActual();
    _capitalEnPrestamos = await DBHelper().getCapitalEnPrestamos();
    _totalCobrado = await DBHelper().sumarTotalCobrado();
    _totalPendiente = await DBHelper().sumarPendiente();
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AndryPrestamosApp.azulOscuro,
      appBar: AppBar(
        backgroundColor: AndryPrestamosApp.azulOscuro,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Capital',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf,
                color: AndryPrestamosApp.dorado),
            tooltip: 'Imprimir Estado',
            onPressed: _imprimirEstado,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AndryPrestamosApp.dorado,
          labelColor: AndryPrestamosApp.dorado,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Historial'),
            Tab(text: 'Estado General'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AndryPrestamosApp.dorado))
          : TabBarView(
              controller: _tab,
              children: [
                _buildHistorial(),
                _buildEstadoGeneral(),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'retiro',
            backgroundColor: AndryPrestamosApp.rojoRetiro,
            onPressed: () => _mostrarDialogo(false),
            child: const Icon(Icons.remove, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'inyeccion',
            backgroundColor: AndryPrestamosApp.verdeClaro,
            onPressed: () => _mostrarDialogo(true),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorial() {
    if (_movimientos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white12),
            SizedBox(height: 12),
            Text('Sin movimientos aún',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movimientos.length,
      itemBuilder: (_, i) => _buildMovimientoTile(_movimientos[i]),
    );
  }

  Widget _buildMovimientoTile(MovimientoCapital m) {
    Color color;
    IconData icon;
    switch (m.tipo) {
      case 'inyeccion':
        color = AndryPrestamosApp.verdeClaro;
        icon = Icons.arrow_downward;
        break;
      case 'retiro':
        color = AndryPrestamosApp.rojoRetiro;
        icon = Icons.arrow_upward;
        break;
      case 'prestamo_otorgado':
        color = const Color(0xFFFFA726);
        icon = Icons.attach_money;
        break;
      case 'pago_recibido':
        color = const Color(0xFF4FC3F7);
        icon = Icons.payments;
        break;
      default:
        color = Colors.white54;
        icon = Icons.swap_horiz;
    }

    final fecha = _parseFecha(m.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AndryPrestamosApp.azulSuperficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.tipoLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (m.descripcion != null && m.descripcion!.isNotEmpty)
                  Text(m.descripcion!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(fecha,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${m.esEntrada ? "+" : "-"} RD\$ ${m.monto.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoGeneral() {
    final totalCapital = _capitalActual + _capitalEnPrestamos;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _estadoCard(
            'Capital en Caja',
            _capitalActual,
            Icons.account_balance_wallet,
            AndryPrestamosApp.verdeClaro,
            'Dinero disponible para prestar',
          ),
          const SizedBox(height: 12),
          _estadoCard(
            'Capital en Préstamos',
            _capitalEnPrestamos,
            Icons.trending_up,
            const Color(0xFFFFA726),
            'Capital activo circulando',
          ),
          const SizedBox(height: 12),
          _estadoCard(
            'Total Cobrado',
            _totalCobrado,
            Icons.check_circle,
            const Color(0xFF4FC3F7),
            'Ingresos por pagos recibidos',
          ),
          const SizedBox(height: 12),
          _estadoCard(
            'Pendiente por Cobrar',
            _totalPendiente,
            Icons.schedule,
            AndryPrestamosApp.rojoRetiro,
            'Cuotas aún no pagadas',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AndryPrestamosApp.azulPrincipal,
                  AndryPrestamosApp.azulProfundo
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics,
                    color: AndryPrestamosApp.dorado, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CAPITAL TOTAL',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 1.2)),
                      Text('RD\$ ${totalCapital.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text('Caja + Préstamos activos',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _imprimirEstado,
              icon: const Icon(Icons.print),
              label: const Text('Imprimir Estado General'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AndryPrestamosApp.dorado,
                foregroundColor: AndryPrestamosApp.azulOscuro,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _estadoCard(
      String titulo, double monto, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AndryPrestamosApp.azulSuperficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                Text('RD\$ ${monto.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(sub,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogo(bool esInyeccion) async {
    final ctrl = TextEditingController();
    final descCtrl = TextEditingController();
    final color = esInyeccion
        ? AndryPrestamosApp.verdeClaro
        : AndryPrestamosApp.rojoRetiro;
    final titulo = esInyeccion ? 'Inyectar Capital' : 'Retirar Capital';

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AndryPrestamosApp.azulSuperficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(esInyeccion ? Icons.add_circle : Icons.remove_circle,
                  color: color, size: 40),
              const SizedBox(height: 12),
              Text(titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Monto (RD\$)',
                  labelStyle: TextStyle(color: color),
                  prefixIcon: Icon(Icons.monetization_on, color: color),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color),
                  ),
                  filled: true,
                  fillColor: color.withOpacity(0.07),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.notes, color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final monto =
                            double.tryParse(ctrl.text.replaceAll(',', '.'));
                        if (monto == null || monto <= 0) return;
                        final desc = descCtrl.text.trim().isEmpty
                            ? (esInyeccion
                                ? 'Inyección de capital'
                                : 'Retiro de capital')
                            : descCtrl.text.trim();
                        await DBHelper().insertMovimientoCapital(
                          MovimientoCapital(
                            tipo: esInyeccion ? 'inyeccion' : 'retiro',
                            monto: monto,
                            descripcion: desc,
                            fecha: DateTime.now().toIso8601String(),
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _cargar();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirmar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _imprimirEstado() async {
    final prestamista = await DBHelper().getPrestamistaUnico();
    final movimientos = await DBHelper().getMovimientosCapital();
    final totalCapital = _capitalActual + _capitalEnPrestamos;
    final ahora = DateTime.now();

    final pdf = pw.Document();

    // Carga el logo Y&Y para incrustarlo en el header del PDF.
    pw.MemoryImage? logoImg;
    try {
      final logoData = await rootBundle.load(AndryPrestamosApp.logoAsset);
      logoImg = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logoImg = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Header con logo Y&Y
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1A3A6B'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImg != null)
                  pw.Container(
                    width: 80,
                    height: 80,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                  ),
                if (logoImg != null) pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Y&Y PRÉSTAMOS',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          )),
                      pw.SizedBox(height: 4),
                      pw.Text('Estado General de Capital',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#CCCCCC'),
                            fontSize: 14,
                          )),
                      pw.SizedBox(height: 8),
                      pw.Text(
                          'Generado: ${ahora.day}/${ahora.month}/${ahora.year} ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')}',
                          style: pw.TextStyle(
                              color: PdfColor.fromHex('#AAAAAA'),
                              fontSize: 11)),
                      if (prestamista != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Prestamista: ${prestamista.nombre}',
                            style: pw.TextStyle(
                                color: PdfColors.white, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Resumen financiero
          pw.Text('RESUMEN FINANCIERO',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1A6B2A'))),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromHex('#DDDDDD'), width: 0.5),
            children: [
              _pdfRow('Capital Disponible (Caja)',
                  'RD\$ ${_capitalActual.toStringAsFixed(2)}',
                  bold: true),
              _pdfRow('Capital en Préstamos Activos',
                  'RD\$ ${_capitalEnPrestamos.toStringAsFixed(2)}'),
              _pdfRow(
                  'CAPITAL TOTAL', 'RD\$ ${totalCapital.toStringAsFixed(2)}',
                  bold: true, highlight: true),
              _pdfRow('Total Cobrado (Ingresos)',
                  'RD\$ ${_totalCobrado.toStringAsFixed(2)}'),
              _pdfRow('Pendiente por Cobrar',
                  'RD\$ ${_totalPendiente.toStringAsFixed(2)}'),
            ],
          ),
          pw.SizedBox(height: 24),

          // Historial de movimientos
          pw.Text('HISTORIAL DE MOVIMIENTOS DE CAPITAL',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1A6B2A'))),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromHex('#DDDDDD'), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromHex('#E8F5E9')),
                children: [
                  _pdfHeader('Fecha'),
                  _pdfHeader('Descripción'),
                  _pdfHeader('Tipo'),
                  _pdfHeader('Monto'),
                ],
              ),
              ...movimientos.map((m) {
                final fecha = _parseFecha(m.fecha);
                return pw.TableRow(children: [
                  _pdfCell(fecha),
                  _pdfCell(m.descripcion ?? m.tipoLabel),
                  _pdfCell(m.tipoLabel, small: true),
                  _pdfCell(
                    '${m.esEntrada ? "+" : "-"} RD\$ ${m.monto.toStringAsFixed(2)}',
                    color: m.esEntrada
                        ? PdfColor.fromHex('#2E7D32')
                        : PdfColor.fromHex('#C62828'),
                  ),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text('Powered by ${AndryPrestamosApp.creadorFirma}',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColor.fromHex('#999999'))),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (fmt) async => await pdf.save());
  }

  pw.TableRow _pdfRow(String label, String value,
      {bool bold = false, bool highlight = false}) {
    return pw.TableRow(
      decoration: highlight
          ? pw.BoxDecoration(color: PdfColor.fromHex('#E8F5E9'))
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 11)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 11,
                  color: highlight ? PdfColor.fromHex('#1A6B2A') : null),
              textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  pw.Widget _pdfHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  pw.Widget _pdfCell(String text, {PdfColor? color, bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: small ? 8 : 10, color: color)),
    );
  }

  String _parseFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return fecha.length > 10 ? fecha.substring(0, 10) : fecha;
    }
  }
}
