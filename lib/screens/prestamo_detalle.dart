import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../database/db_helper.dart';
import '../models/cuota.dart';
import '../models/pago.dart';
import '../models/prestamo.dart';
import '../models/cliente.dart';
import '../models/prestamista.dart';
import '../utils/calculadora_penalidad.dart';
import '../utils/formato.dart';
import '../utils/recibo_pdf.dart';
import '../main.dart';

class PrestamoDetalle extends StatefulWidget {
  final int prestamoId;
  const PrestamoDetalle({super.key, required this.prestamoId});

  @override
  State<PrestamoDetalle> createState() => _PrestamoDetalleState();
}

class _PrestamoDetalleState extends State<PrestamoDetalle> {
  Prestamo? prestamo;
  Cliente? cliente;
  Prestamista? prestamista;
  List<Cuota> cuotas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    prestamo = await DBHelper().getPrestamo(widget.prestamoId);
    prestamista = await DBHelper().getPrestamistaUnico();
    if (prestamo != null) {
      cliente = await DBHelper().getCliente(prestamo!.clienteId);
      cuotas = await DBHelper().getCuotas(prestamo!.id!);
    }
    // Actualiza estado segun cuotas pendientes
    if (prestamo != null) {
      final pendientes = cuotas.where((c) => !c.estaPagada).length;
      final hayMora = cuotas.any((c) => !c.estaPagada && estaEnMora(c));
      String nuevoEstado;
      if (pendientes == 0) {
        nuevoEstado = 'pagado';
      } else if (hayMora) {
        nuevoEstado = 'mora';
      } else {
        nuevoEstado = 'activo';
      }
      if (nuevoEstado != prestamo!.estado) {
        prestamo!.estado = nuevoEstado;
        await DBHelper().updatePrestamo(prestamo!);
      }
    }
    if (mounted) setState(() => cargando = false);
  }

  double get _totalCobrado =>
      cuotas.fold(0.0, (a, c) => a + c.montoPagado + c.penalidadAplicada);

  double get _totalPenalidadVigente {
    if (prestamo == null) return 0;
    return cuotas.fold(
      0.0,
      (a, c) =>
          a +
          calcularPenalidad(c, prestamo!.modalidad, prestamo!.montoPenalidad),
    );
  }

  double get _saldoPendiente {
    if (prestamo == null) return 0;
    return cuotas.fold(0.0, (a, c) => a + (c.monto - c.montoPagado));
  }

  Future<void> _llamarCliente() async {
    final t = cliente?.telefono ?? '';
    if (t.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: t);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _enviarRecordatorioWhatsapp() async {
    if (cliente == null || prestamo == null) return;
    final t = cliente!.telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El cliente no tiene telefono registrado')));
      return;
    }

    // Buscar proxima cuota pendiente
    Cuota? prox;
    int diasMin = 1 << 30;
    for (final c in cuotas) {
      if (!c.estaPagada) {
        final d = diasParaVencer(c);
        if (d.abs() < diasMin.abs()) {
          diasMin = d;
          prox = c;
        }
      }
    }

    String mensaje;
    if (prox == null) {
      mensaje =
          'Hola ${cliente!.nombre}, tu prestamo en *${AndryPrestamosApp.nombreNegocio}* esta al dia. Gracias por tu confianza.';
    } else {
      final penalidad = calcularPenalidad(
          prox, prestamo!.modalidad, prestamo!.montoPenalidad);
      final total = (prox.monto - prox.montoPagado) + penalidad;

      if (diasMin < 0) {
        mensaje =
            'Hola ${cliente!.nombre}, te recordamos que la cuota #${prox.numero} '
            'venció el ${formatoFechaStr(prox.fechaVencimiento)} (${-diasMin} días de retraso).\n'
            'Monto: ${formatoMoneda(prox.monto - prox.montoPagado)}\n'
            'Penalidad acumulada: ${formatoMoneda(penalidad)}\n'
            '*Total a pagar: ${formatoMoneda(total)}*\n\n'
            '${AndryPrestamosApp.nombreNegocio} - ${AndryPrestamosApp.telefonoDueno}';
      } else if (diasMin == 0) {
        mensaje =
            'Hola ${cliente!.nombre}, te recordamos que HOY vence la cuota #${prox.numero}.\n'
            'Monto: ${formatoMoneda(prox.monto - prox.montoPagado)}\n\n'
            '${AndryPrestamosApp.nombreNegocio} - ${AndryPrestamosApp.telefonoDueno}';
      } else {
        mensaje =
            'Hola ${cliente!.nombre}, te recordamos que tu próxima cuota #${prox.numero} '
            'vence el ${formatoFechaStr(prox.fechaVencimiento)} (en $diasMin día${diasMin == 1 ? "" : "s"}).\n'
            'Monto: ${formatoMoneda(prox.monto - prox.montoPagado)}\n\n'
            '${AndryPrestamosApp.nombreNegocio} - ${AndryPrestamosApp.telefonoDueno}';
      }
    }

    // Asegurar codigo de pais para Dominicana si no lo tiene
    String numero = t;
    if (!numero.startsWith('1') && numero.length == 10) {
      numero = '1$numero';
    }

    final uri =
        Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp')),
    );
  }

  Future<void> _registrarPago(Cuota cuota) async {
    final penalidad =
        calcularPenalidad(cuota, prestamo!.modalidad, prestamo!.montoPenalidad);
    final saldoCuota = cuota.monto - cuota.montoPagado;
    final totalSugerido = saldoCuota + penalidad;
    final controller =
        TextEditingController(text: totalSugerido.toStringAsFixed(2));
    final obsController = TextEditingController();
    final retraso = diasDeRetraso(cuota);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pago cuota #${cuota.numero}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filaPago('Saldo cuota:', formatoMoneda(saldoCuota)),
              _filaPago(
                'Penalidad acumulada:',
                formatoMoneda(penalidad),
                color: penalidad > 0 ? AndryPrestamosApp.rojoMora : Colors.grey,
              ),
              if (retraso > 0 && penalidad > 0)
                Text(
                  '($retraso día${retraso == 1 ? "" : "s"} de retraso · '
                  '${formatoMoneda(penalidadPorDia(prestamo!.modalidad, prestamo!.montoPenalidad))}/día)',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              const Divider(),
              _filaPago('Total sugerido:', formatoMoneda(totalSugerido),
                  bold: true),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto a cobrar (RD\$)',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final cobrado = double.tryParse(controller.text) ?? 0;
              Navigator.pop(context, {
                'cobrado': cobrado,
                'penalidad': penalidad,
                'obs': obsController.text,
              });
            },
            child: const Text('Registrar pago'),
          ),
        ],
      ),
    );

    if (result == null) return;

    double cobrado = result['cobrado'] as double;
    final double penAplicada = result['penalidad'] as double;
    final String obs = result['obs'] as String;

    // El monto cubre primero la penalidad y luego el capital de la cuota
    double penalidadFinal = 0;
    double aPrincipal = cobrado;
    if (penAplicada > 0) {
      if (cobrado >= penAplicada) {
        penalidadFinal = penAplicada;
        aPrincipal = cobrado - penAplicada;
      } else {
        penalidadFinal = cobrado;
        aPrincipal = 0;
      }
    }

    // Actualizar cuota
    cuota.montoPagado += aPrincipal;
    cuota.penalidadAplicada += penalidadFinal;
    final ahora = DateTime.now();
    final fechaStr = ahora.toIso8601String().substring(0, 10);
    if (cuota.montoPagado + 0.005 >= cuota.monto) {
      cuota.pagada = 1;
      cuota.fechaPago = fechaStr;
    }
    await DBHelper().updateCuota(cuota);

    // Insertar pago y recuperar su ID asignado
    final pagoTmp = Pago(
      cuotaId: cuota.id!,
      monto: aPrincipal,
      penalidad: penalidadFinal,
      fecha: fechaStr,
      observaciones: obs,
    );
    final nuevoId = await DBHelper().insertPago(pagoTmp);
    final pago = Pago(
      id: nuevoId,
      cuotaId: pagoTmp.cuotaId,
      monto: pagoTmp.monto,
      penalidad: pagoTmp.penalidad,
      fecha: pagoTmp.fecha,
      observaciones: pagoTmp.observaciones,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Pago registrado: ${formatoMoneda(aPrincipal + penalidadFinal)}'),
      backgroundColor: AndryPrestamosApp.verdePrincipal,
    ));

    // Refrescar saldo antes de mostrar acciones del recibo
    await _cargar();

    if (!mounted) return;
    // Ofrecer acciones para el recibo recien generado
    await _mostrarAccionesRecibo(cuota, pago);
  }

  /// Muestra un dialogo con las opciones de envio/impresion del recibo
  /// recien generado luego de registrar un pago.
  Future<void> _mostrarAccionesRecibo(Cuota cuota, Pago pago) async {
    if (cliente == null || prestamo == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: AndryPrestamosApp.verdePrincipal, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Recibo #${pago.id} generado',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cuota #${cuota.numero} · ${formatoMoneda(pago.monto + pago.penalidad)}',
                  style: const TextStyle(color: Colors.white60),
                ),
                const Divider(height: 24),
                _accionRecibo(
                  icono: Icons.chat,
                  color: AndryPrestamosApp.verdeOscuro,
                  titulo: 'Enviar por WhatsApp',
                  subtitulo: 'Envia el recibo en texto al cliente',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _enviarReciboWhatsapp(cuota, pago);
                  },
                ),
                _accionRecibo(
                  icono: Icons.share,
                  color: Colors.blue.shade300,
                  titulo: 'Compartir / Enviar como PDF',
                  subtitulo: 'Comparte el recibo en formato PDF',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _compartirReciboPdf(cuota, pago);
                  },
                ),
                _accionRecibo(
                  icono: Icons.picture_as_pdf,
                  color: Colors.deepOrange,
                  titulo: 'Vista previa / Imprimir PDF',
                  subtitulo:
                      'Abre la vista del sistema (otras impresoras / PDF)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _vistaPreviaReciboPdf(cuota, pago);
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _accionRecibo({
    required IconData icono,
    required Color color,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icono, color: color),
        ),
        title:
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitulo,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ============ ENVIOS / IMPRESIONES DEL RECIBO ============

  Future<void> _enviarReciboWhatsapp(Cuota cuota, Pago pago) async {
    if (cliente == null || prestamo == null) return;
    final texto = generarReciboPagoTexto(
      prestamista: prestamista,
      cliente: cliente!,
      prestamo: prestamo!,
      cuota: cuota,
      pago: pago,
      saldoPendiente: _saldoPendiente,
    );
    final t = cliente!.telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.isEmpty) {
      // Sin telefono: compartir generico
      await Share.share(texto, subject: 'Recibo de pago');
      return;
    }
    String numero = t;
    if (!numero.startsWith('1') && numero.length == 10) {
      numero = '1$numero';
    }
    final uri =
        Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(texto)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(texto, subject: 'Recibo de pago');
    }
  }

  Future<void> _compartirReciboPdf(Cuota cuota, Pago pago) async {
    if (cliente == null || prestamo == null) return;
    final bytes = await generarReciboPagoPdf(
      prestamista: prestamista,
      cliente: cliente!,
      prestamo: prestamo!,
      cuota: cuota,
      pago: pago,
      saldoPendiente: _saldoPendiente,
    );
    final nombre =
        'recibo_${pago.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: nombre, mimeType: 'application/pdf')],
      text: 'Recibo de pago #${pago.id} - ${AndryPrestamosApp.nombreNegocio}',
    );
  }

  Future<void> _vistaPreviaReciboPdf(Cuota cuota, Pago pago) async {
    if (cliente == null || prestamo == null) return;
    await Printing.layoutPdf(
      onLayout: (format) => generarReciboPagoPdf(
        prestamista: prestamista,
        cliente: cliente!,
        prestamo: prestamo!,
        cuota: cuota,
        pago: pago,
        saldoPendiente: _saldoPendiente,
      ),
      name: 'Recibo_${pago.id}',
    );
  }

  // ============ ACCIONES DEL PRESTAMO COMPLETO ============

  /// Menu de opciones para el detalle del prestamo (imprimir / compartir).
  Future<void> _mostrarAccionesPrestamo() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.description,
                        color: AndryPrestamosApp.verdePrincipal, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Detalle del prestamo',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _accionRecibo(
                  icono: Icons.share,
                  color: Colors.blue.shade300,
                  titulo: 'Compartir como PDF',
                  subtitulo: 'Comparte el detalle del prestamo',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _compartirDetallePdf();
                  },
                ),
                _accionRecibo(
                  icono: Icons.picture_as_pdf,
                  color: Colors.deepOrange,
                  titulo: 'Vista previa / Imprimir PDF',
                  subtitulo:
                      'Abre la vista del sistema (otras impresoras / PDF)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _vistaPreviaDetallePdf();
                  },
                ),
                _accionRecibo(
                  icono: Icons.text_snippet,
                  color: AndryPrestamosApp.azulPrincipal,
                  titulo: 'Compartir como texto',
                  subtitulo: 'Comparte el resumen en texto',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _compartirReciboTexto();
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _compartirDetallePdf() async {
    if (cliente == null || prestamo == null) return;
    final bytes = await generarDetallePrestamoPdf(
      prestamista: prestamista,
      cliente: cliente!,
      prestamo: prestamo!,
      cuotas: cuotas,
      totalCobrado: _totalCobrado,
      saldoPendiente: _saldoPendiente,
      moraVigente: _totalPenalidadVigente,
    );
    final nombre =
        'prestamo_${prestamo!.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: nombre, mimeType: 'application/pdf')],
      text:
          'Detalle prestamo #${prestamo!.id} - ${AndryPrestamosApp.nombreNegocio}',
    );
  }

  Future<void> _vistaPreviaDetallePdf() async {
    if (cliente == null || prestamo == null) return;
    await Printing.layoutPdf(
      onLayout: (format) => generarDetallePrestamoPdf(
        prestamista: prestamista,
        cliente: cliente!,
        prestamo: prestamo!,
        cuotas: cuotas,
        totalCobrado: _totalCobrado,
        saldoPendiente: _saldoPendiente,
        moraVigente: _totalPenalidadVigente,
      ),
      name: 'Prestamo_${prestamo!.id}',
    );
  }

  Future<void> _compartirReciboTexto() async {
    if (prestamo == null || cliente == null) return;
    final buf = StringBuffer();
    buf.writeln('========================');
    buf.writeln('   ${prestamista?.nombre ?? AndryPrestamosApp.nombreNegocio}');
    buf.writeln(
        '   Tel: ${prestamista?.telefono ?? AndryPrestamosApp.telefonoDueno}');
    buf.writeln('========================');
    buf.writeln('Cliente: ${cliente!.nombre}');
    buf.writeln('Cedula: ${cliente!.cedula}');
    buf.writeln('Prestamo #${prestamo!.id}');
    buf.writeln('Capital: ${formatoMoneda(prestamo!.capital)}');
    buf.writeln('Interes: ${prestamo!.tasaInteres}%');
    buf.writeln('Total: ${formatoMoneda(prestamo!.montoTotal)}');
    buf.writeln('Modalidad: ${modalidadLabel(prestamo!.modalidad)}');
    buf.writeln('Cuotas: ${prestamo!.numCuotas}');
    buf.writeln('------------------------');
    buf.writeln('CRONOGRAMA:');
    for (final c in cuotas) {
      final estado =
          c.estaPagada ? 'PAGADO' : (estaEnMora(c) ? 'MORA' : 'Pendiente');
      buf.writeln(
          '#${c.numero} ${formatoFechaStr(c.fechaVencimiento)} ${formatoMoneda(c.monto)} - $estado');
    }
    buf.writeln('------------------------');
    buf.writeln('Total cobrado: ${formatoMoneda(_totalCobrado)}');
    buf.writeln('Saldo: ${formatoMoneda(_saldoPendiente)}');
    buf.writeln('Mora vigente: ${formatoMoneda(_totalPenalidadVigente)}');
    buf.writeln('========================');
    buf.writeln('Sistema desarrollado por');
    buf.writeln('${AndryPrestamosApp.creadorSistema}');
    buf.writeln('Tel: ${AndryPrestamosApp.creadorTelefono}');
    await Share.share(buf.toString(),
        subject: 'Detalle ${AndryPrestamosApp.nombreNegocio}');
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (prestamo == null) {
      return const Scaffold(
          body: Center(child: Text('Prestamo no encontrado')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Prestamo #${prestamo!.id}'),
        actions: [
          if (cliente?.telefono.isNotEmpty == true)
            IconButton(
              tooltip: 'WhatsApp recordatorio',
              icon: const Icon(Icons.chat),
              onPressed: _enviarRecordatorioWhatsapp,
            ),
          IconButton(
            tooltip: 'Imprimir / Compartir detalle',
            icon: const Icon(Icons.print),
            onPressed: _mostrarAccionesPrestamo,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header del cliente
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          AndryPrestamosApp.verdePrincipal.withOpacity(0.15),
                      child: Text(
                        cliente?.nombre.isNotEmpty == true
                            ? cliente!.nombre[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AndryPrestamosApp.verdeClaro,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cliente?.nombre ?? '',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          if (cliente?.cedula.isNotEmpty == true)
                            Text('Cedula: ${cliente!.cedula}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                          if (cliente?.telefono.isNotEmpty == true)
                            Text('Tel: ${cliente!.telefono}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                        ],
                      ),
                    ),
                    if (cliente?.telefono.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.blue),
                        onPressed: _llamarCliente,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Info del prestamo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_money,
                            color: AndryPrestamosApp.verdePrincipal),
                        const SizedBox(width: 8),
                        const Text('DATOS DEL PRESTAMO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AndryPrestamosApp.verdeClaro,
                              letterSpacing: 1,
                            )),
                      ],
                    ),
                    const Divider(),
                    _info('Capital prestado', formatoMoneda(prestamo!.capital)),
                    _info('Interes',
                        '${prestamo!.tasaInteres.toStringAsFixed(2)}%'),
                    _info('Monto total', formatoMoneda(prestamo!.montoTotal)),
                    _info('Modalidad', modalidadLabel(prestamo!.modalidad)),
                    _info('Cuotas', '${prestamo!.numCuotas}'),
                    _info('Inicio', formatoFechaStr(prestamo!.fechaInicio)),
                    _info(
                      'Penalidad por dia',
                      formatoMoneda(penalidadPorDia(
                          prestamo!.modalidad, prestamo!.montoPenalidad)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Resumen financiero
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AndryPrestamosApp.verdePrincipal.withOpacity(0.08),
                    AndryPrestamosApp.verdePrincipal.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AndryPrestamosApp.verdePrincipal.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _info('Total cobrado', formatoMoneda(_totalCobrado),
                      bold: true, color: AndryPrestamosApp.verdePrincipal),
                  _info('Saldo pendiente', formatoMoneda(_saldoPendiente),
                      bold: true, color: Colors.orange.shade400),
                  _info('Mora vigente (no cobrada)',
                      formatoMoneda(_totalPenalidadVigente),
                      bold: true, color: AndryPrestamosApp.rojoMora),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.list_alt,
                      size: 18, color: AndryPrestamosApp.verdeClaro),
                  SizedBox(width: 6),
                  Text('CRONOGRAMA DE CUOTAS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AndryPrestamosApp.verdeClaro,
                        letterSpacing: 1,
                      )),
                ],
              ),
            ),
            ...cuotas.map((c) => _cuotaTile(c)),
            const SizedBox(height: 18),
            Center(
              child: Text(
                AndryPrestamosApp.creadorFirma,
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _info(String t, String v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t,
              style: TextStyle(
                  fontSize: bold ? 14 : 13,
                  color: bold ? Colors.white : Colors.white70)),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 15 : 13,
                  color: color)),
        ],
      ),
    );
  }

  Widget _filaPago(String label, String valor,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(valor,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }

  Widget _cuotaTile(Cuota c) {
    final penalidad =
        calcularPenalidad(c, prestamo!.modalidad, prestamo!.montoPenalidad);
    final retraso = diasDeRetraso(c);
    final mora = estaEnMora(c);
    final dias = diasParaVencer(c);

    Color borde;
    Color iconColor;
    IconData icono;
    String estadoText;

    if (c.estaPagada) {
      borde = AndryPrestamosApp.verdePrincipal;
      iconColor = AndryPrestamosApp.verdePrincipal;
      icono = Icons.check_circle;
      estadoText = 'PAGADA';
    } else if (mora) {
      borde = AndryPrestamosApp.rojoMora;
      iconColor = AndryPrestamosApp.rojoMora;
      icono = Icons.warning;
      estadoText = 'EN MORA';
    } else if (dias == 0) {
      borde = AndryPrestamosApp.naranjaAlerta;
      iconColor = AndryPrestamosApp.naranjaAlerta;
      icono = Icons.today;
      estadoText = 'VENCE HOY';
    } else {
      borde = const Color(0xFF546E7A);
      iconColor = Colors.blue.shade300;
      icono = Icons.schedule;
      estadoText = 'PENDIENTE';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AndryPrestamosApp.azulSuperficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borde.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(icono, color: iconColor, size: 32),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cuota #${c.numero}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            Text(formatoMoneda(c.monto),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vence: ${formatoFechaStr(c.fechaVencimiento)} · $estadoText',
                style: TextStyle(color: iconColor)),
            if (c.montoPagado > 0)
              Text('Pagado: ${formatoMoneda(c.montoPagado)}',
                  style:
                      const TextStyle(color: AndryPrestamosApp.verdePrincipal)),
            if (c.penalidadAplicada > 0)
              Text('Penalidad cobrada: ${formatoMoneda(c.penalidadAplicada)}',
                  style: TextStyle(color: Colors.orange.shade400)),
            if (!c.estaPagada && mora)
              Text(
                'Retraso: $retraso día${retraso == 1 ? "" : "s"} · '
                'Mora actual: ${formatoMoneda(penalidad)}',
                style: const TextStyle(
                    color: AndryPrestamosApp.rojoMora,
                    fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: c.estaPagada
            ? Wrap(
                children: [
                  IconButton(
                    icon: const Icon(Icons.receipt_long,
                        color: AndryPrestamosApp.verdePrincipal),
                    tooltip: 'Recibo de esta cuota',
                    onPressed: () => _mostrarRecibosCuota(c),
                  ),
                ],
              )
            : Wrap(
                children: [
                  if (c.montoPagado > 0)
                    IconButton(
                      icon: const Icon(Icons.receipt_long,
                          color: AndryPrestamosApp.verdePrincipal),
                      tooltip: 'Recibos previos',
                      onPressed: () => _mostrarRecibosCuota(c),
                    ),
                  IconButton(
                    icon: const Icon(Icons.payment,
                        color: AndryPrestamosApp.verdePrincipal, size: 28),
                    tooltip: 'Registrar pago',
                    onPressed: () => _registrarPago(c),
                  ),
                ],
              ),
      ),
    );
  }

  /// Muestra los pagos (recibos) previamente registrados para una cuota
  /// y permite re-imprimir o re-compartir cualquiera de ellos.
  Future<void> _mostrarRecibosCuota(Cuota c) async {
    final pagos = await DBHelper().getPagosPorCuota(c.id!);
    if (!mounted) return;
    if (pagos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay pagos registrados en esta cuota')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recibos de la cuota #${c.numero}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView(
                    shrinkWrap: true,
                    children: pagos
                        .map((p) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.receipt,
                                    color: AndryPrestamosApp.verdePrincipal),
                                title: Text(
                                    'Recibo #${p.id} - ${formatoMoneda(p.monto + p.penalidad)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle:
                                    Text('Fecha: ${formatoFechaStr(p.fecha)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _mostrarAccionesRecibo(c, p);
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _mostrarAccionesRecibo(c, p);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
