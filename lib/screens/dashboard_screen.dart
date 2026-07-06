import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/cliente.dart';
import '../models/prestamo.dart';
import '../models/cuota.dart';
import '../utils/calculadora_penalidad.dart';
import '../utils/formato.dart';
import '../main.dart';
import 'prestamo_detalle.dart';

/// Resumen por cliente: agrupa toda su informacion relevante.
class _ResumenCliente {
  final Cliente cliente;
  final List<Prestamo> prestamos;
  final List<Cuota> cuotas;

  // Calculos
  double saldoPendiente = 0;
  double moraVigente = 0;
  int cuotasPendientes = 0;
  int cuotasEnMora = 0;
  Cuota? proximaCuota;
  int diasParaProxima = 0;
  Prestamo? prestamoProximaCuota;

  _ResumenCliente({
    required this.cliente,
    required this.prestamos,
    required this.cuotas,
  });

  bool get tieneMora => cuotasEnMora > 0;
  bool get vencidaHoy {
    if (proximaCuota == null) return false;
    return diasParaProxima == 0 && !proximaCuota!.estaPagada;
  }

  double get totalAdeudado => saldoPendiente + moraVigente;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final db = DBHelper();

  double capital = 0, cobrado = 0, pendiente = 0, totalMora = 0;
  int vencidasHoy = 0, cuotasMora = 0;

  List<_ResumenCliente> resumenes = [];
  bool cargando = true;

  // Filtro: 'todos' | 'mora' | 'hoy' | 'al_dia'
  String _filtro = 'todos';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => cargando = true);

    capital = await db.sumarCapitalActivo();
    cobrado = await db.sumarTotalCobrado();
    pendiente = await db.sumarPendiente();
    vencidasHoy = await db.contarCuotasVencidasHoy();
    cuotasMora = await db.contarCuotasEnMora();

    final clientes = await db.getClientes();
    final prestamos = await db.getPrestamos();
    final cuotas = await db.getTodasLasCuotas();

    final prestamosPorCliente = <int, List<Prestamo>>{};
    for (final p in prestamos) {
      (prestamosPorCliente[p.clienteId] ??= []).add(p);
    }

    final cuotasPorPrestamo = <int, List<Cuota>>{};
    for (final cu in cuotas) {
      (cuotasPorPrestamo[cu.prestamoId] ??= []).add(cu);
    }

    final List<_ResumenCliente> tmp = [];
    double moraSum = 0;

    for (final c in clientes) {
      final prestamosC = prestamosPorCliente[c.id] ?? const <Prestamo>[];
      final List<Cuota> cuotasC = [];
      for (final p in prestamosC) {
        cuotasC.addAll(cuotasPorPrestamo[p.id] ?? const <Cuota>[]);
      }

      final r = _ResumenCliente(
        cliente: c,
        prestamos: prestamosC,
        cuotas: cuotasC,
      );

      Cuota? prox;
      int diasMin = 1 << 30;

      for (final p in prestamosC) {
        final cuotasPrestamo = cuotasPorPrestamo[p.id] ?? const <Cuota>[];
        for (final cu in cuotasPrestamo) {
          if (!cu.estaPagada) {
            r.cuotasPendientes++;
            r.saldoPendiente += (cu.monto - cu.montoPagado);

            final mora = calcularPenalidad(cu, p.modalidad, p.montoPenalidad);
            if (mora > 0) {
              r.cuotasEnMora++;
              r.moraVigente += mora;
            }

            final diff = diasParaVencer(cu);
            if (diff >= 0 && diff < diasMin) {
              diasMin = diff;
              prox = cu;
              r.prestamoProximaCuota = p;
            }
          }
        }
      }

      // Si no hay cuota futura pero hay cuotas en mora, tomamos la mas antigua vencida
      if (prox == null) {
        Cuota? masAntigua;
        int diasMax = -1;
        for (final p in prestamosC) {
          final cuotasPrestamo = cuotasPorPrestamo[p.id] ?? const <Cuota>[];
          for (final cu in cuotasPrestamo) {
            if (!cu.estaPagada) {
              final d = diasDeRetraso(cu);
              if (d > diasMax) {
                diasMax = d;
                masAntigua = cu;
                r.prestamoProximaCuota = p;
              }
            }
          }
        }
        if (masAntigua != null) {
          prox = masAntigua;
          diasMin = -diasMax;
        }
      }

      r.proximaCuota = prox;
      r.diasParaProxima = diasMin == (1 << 30) ? 0 : diasMin;

      moraSum += r.moraVigente;

      // Solo mostramos clientes que tengan al menos un prestamo
      if (prestamosC.isNotEmpty) {
        tmp.add(r);
      }
    }

    // Ordenar: primero clientes con mora, luego por proxima cuota mas urgente
    tmp.sort((a, b) {
      if (a.tieneMora != b.tieneMora) {
        return a.tieneMora ? -1 : 1;
      }
      // Ambos en el mismo grupo: el mas urgente primero
      return a.diasParaProxima.compareTo(b.diasParaProxima);
    });

    totalMora = moraSum;
    resumenes = tmp;
    if (mounted) setState(() => cargando = false);
  }

  List<_ResumenCliente> get _resumenesFiltrados {
    switch (_filtro) {
      case 'mora':
        return resumenes.where((r) => r.tieneMora).toList();
      case 'hoy':
        return resumenes.where((r) => r.vencidaHoy).toList();
      case 'al_dia':
        return resumenes
            .where((r) => !r.tieneMora && r.cuotasPendientes > 0)
            .toList();
      default:
        return resumenes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  // KPI superior con alertas
                  _bloqueAlertas(),
                  const SizedBox(height: 12),
                  _kpisGrid(),
                  const SizedBox(height: 18),
                  _filtros(),
                  const SizedBox(height: 8),
                  _seccionClientes(),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Y&Y Prestamos · ${AndryPrestamosApp.telefonoDueno}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------- BLOQUE DE ALERTAS ----------
  Widget _bloqueAlertas() {
    if (vencidasHoy == 0 && cuotasMora == 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AndryPrestamosApp.azulSuperficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AndryPrestamosApp.verdePrincipal),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                color: AndryPrestamosApp.verdeClaro, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Todo al día. No hay cuotas vencidas hoy ni clientes en mora.',
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (vencidasHoy > 0)
          _bannerAlerta(
            color: AndryPrestamosApp.naranjaAlerta,
            icon: Icons.today,
            titulo: 'Cuotas que vencen HOY',
            valor: '$vencidasHoy',
            subtitulo: 'No olvides recordar a tus clientes.',
          ),
        if (cuotasMora > 0) ...[
          if (vencidasHoy > 0) const SizedBox(height: 10),
          _bannerAlerta(
            color: AndryPrestamosApp.rojoMora,
            icon: Icons.warning_amber_rounded,
            titulo: 'Cuotas en MORA',
            valor: '$cuotasMora',
            subtitulo: 'Mora vigente acumulada: ${formatoMoneda(totalMora)}',
          ),
        ],
      ],
    );
  }

  Widget _bannerAlerta({
    required Color color,
    required IconData icon,
    required String titulo,
    required String valor,
    required String subtitulo,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ],
            ),
          ),
          Text(valor,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ---------- KPIS ----------
  Widget _kpisGrid() {
    final kpis = [
      _Kpi('Capital activo', formatoMoneda(capital), Icons.account_balance,
          Colors.blue.shade300),
      _Kpi('Cobrado total', formatoMoneda(cobrado), Icons.trending_up,
          AndryPrestamosApp.verdeClaro),
      _Kpi('Saldo pendiente', formatoMoneda(pendiente), Icons.pending_actions,
          Colors.orange.shade400),
      _Kpi('Mora vigente', formatoMoneda(totalMora), Icons.gavel,
          AndryPrestamosApp.rojoMora),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: kpis.map((k) => _kpiCard(k)).toList(),
    );
  }

  Widget _kpiCard(_Kpi k) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AndryPrestamosApp.azulSuperficieAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: k.color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: k.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(k.icono, size: 16, color: k.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(k.titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(
            k.valor,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: k.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------- FILTROS ----------
  Widget _filtros() {
    final chips = [
      _ChipFiltro('todos', 'Todos', Icons.list),
      _ChipFiltro('mora', 'En mora', Icons.warning),
      _ChipFiltro('hoy', 'Vencen hoy', Icons.today),
      _ChipFiltro('al_dia', 'Al dia', Icons.check_circle),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips.map((c) {
                final selected = _filtro == c.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon,
                            size: 14,
                            color: selected
                                ? Colors.white
                                : AndryPrestamosApp.verdePrincipal),
                        const SizedBox(width: 6),
                        Text(c.label),
                      ],
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _filtro = c.id),
                    selectedColor: AndryPrestamosApp.verdePrincipal,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AndryPrestamosApp.azulSuperficieAlt,
                    side: BorderSide(
                      color: selected
                          ? AndryPrestamosApp.verdePrincipal
                          : AndryPrestamosApp.azulClaro,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- SECCION CLIENTES ----------
  Widget _seccionClientes() {
    final lista = _resumenesFiltrados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 18, color: AndryPrestamosApp.verdeClaro),
              const SizedBox(width: 6),
              const Text(
                'PRESTAMOS POR CLIENTE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AndryPrestamosApp.verdeClaro,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AndryPrestamosApp.verdePrincipal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lista.length}',
                  style: const TextStyle(
                    color: AndryPrestamosApp.verdeClaro,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (lista.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AndryPrestamosApp.azulSuperficieAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'No hay clientes para este filtro.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          )
        else
          ...lista.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _clienteCard(r),
              )),
      ],
    );
  }

  Widget _clienteCard(_ResumenCliente r) {
    Color borde;
    Color cintaColor;
    IconData icono;
    String etiqueta;

    if (r.tieneMora) {
      borde = AndryPrestamosApp.rojoMora;
      cintaColor = AndryPrestamosApp.rojoMora;
      icono = Icons.warning_amber_rounded;
      etiqueta = 'EN MORA';
    } else if (r.vencidaHoy) {
      borde = AndryPrestamosApp.naranjaAlerta;
      cintaColor = AndryPrestamosApp.naranjaAlerta;
      icono = Icons.notifications_active;
      etiqueta = 'VENCE HOY';
    } else if (r.cuotasPendientes > 0) {
      borde = AndryPrestamosApp.verdePrincipal;
      cintaColor = AndryPrestamosApp.verdePrincipal;
      icono = Icons.schedule;
      etiqueta = 'AL DIA';
    } else {
      borde = Colors.grey;
      cintaColor = Colors.grey;
      icono = Icons.check_circle;
      etiqueta = 'COMPLETADO';
    }

    return Container(
      decoration: BoxDecoration(
        color: AndryPrestamosApp.azulSuperficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde.withOpacity(0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera con nombre y badge
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            decoration: BoxDecoration(
              color: cintaColor.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cintaColor.withOpacity(0.2),
                  child: Text(
                    r.cliente.nombre.isNotEmpty
                        ? r.cliente.nombre[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: cintaColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.cliente.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (r.cliente.telefono.isNotEmpty)
                        Text(
                          r.cliente.telefono,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white60),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cintaColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icono, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        etiqueta,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Cuerpo: numeros
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: _miniDato(
                    'Prestamos',
                    '${r.prestamos.length}',
                    Icons.attach_money,
                    AndryPrestamosApp.verdePrincipal,
                  ),
                ),
                Expanded(
                  child: _miniDato(
                    'Cuotas pend.',
                    '${r.cuotasPendientes}',
                    Icons.list_alt,
                    Colors.blue.shade300,
                  ),
                ),
                Expanded(
                  child: _miniDato(
                    'En mora',
                    '${r.cuotasEnMora}',
                    Icons.warning,
                    r.cuotasEnMora > 0
                        ? AndryPrestamosApp.rojoMora
                        : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          // Saldo y mora
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AndryPrestamosApp.azulSuperficieAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AndryPrestamosApp.azulSuperficieAlt),
            ),
            child: Column(
              children: [
                _filaSaldo(
                  'Saldo pendiente',
                  formatoMoneda(r.saldoPendiente),
                  Colors.orange.shade400,
                ),
                if (r.moraVigente > 0) ...[
                  const SizedBox(height: 4),
                  _filaSaldo(
                    'Mora vigente',
                    formatoMoneda(r.moraVigente),
                    AndryPrestamosApp.rojoMora,
                    bold: true,
                  ),
                ],
                const Divider(height: 14),
                _filaSaldo(
                  'TOTAL A COBRAR',
                  formatoMoneda(r.totalAdeudado),
                  AndryPrestamosApp.dorado,
                  bold: true,
                ),
              ],
            ),
          ),
          // Recordatorio de proxima cuota
          if (r.proximaCuota != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: _recordatorioProxima(r),
            ),
          // Boton
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _abrirPrimerPrestamoCliente(r),
                icon: const Icon(Icons.visibility),
                label: const Text('Ver detalle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AndryPrestamosApp.verdePrincipal,
                  side:
                      const BorderSide(color: AndryPrestamosApp.verdePrincipal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordatorioProxima(_ResumenCliente r) {
    final cuota = r.proximaCuota!;
    final dias = r.diasParaProxima;
    final p = r.prestamoProximaCuota;

    Color color;
    IconData icon;
    String mensaje;

    if (dias < 0) {
      color = AndryPrestamosApp.rojoMora;
      icon = Icons.error_outline;
      mensaje =
          'Cuota #${cuota.numero} vencida hace ${-dias} dia${-dias == 1 ? "" : "s"}';
    } else if (dias == 0) {
      color = AndryPrestamosApp.naranjaAlerta;
      icon = Icons.notifications_active;
      mensaje = 'Cuota #${cuota.numero} vence HOY';
    } else if (dias <= 3) {
      color = AndryPrestamosApp.doradoOscuro;
      icon = Icons.schedule;
      mensaje =
          'Cuota #${cuota.numero} vence en $dias dia${dias == 1 ? "" : "s"}';
    } else {
      color = AndryPrestamosApp.verdePrincipal;
      icon = Icons.event_available;
      mensaje =
          'Proxima cuota #${cuota.numero}: ${formatoFechaStr(cuota.fechaVencimiento)}';
    }

    double penalidad = 0;
    if (p != null) {
      penalidad = calcularPenalidad(cuota, p.modalidad, p.montoPenalidad);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                formatoMoneda(cuota.monto - cuota.montoPagado),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (penalidad > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text(
                '+ Penalidad acumulada: ${formatoMoneda(penalidad)}',
                style: TextStyle(
                  color: AndryPrestamosApp.rojoMora,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaSaldo(String label, String valor, Color color,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? Colors.white : Colors.white60,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _miniDato(String label, String valor, IconData icono, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, color: color, size: 18),
        const SizedBox(height: 2),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  Future<void> _abrirPrimerPrestamoCliente(_ResumenCliente r) async {
    // Si tiene un prestamo en mora, abre ese; si no, abre el mas reciente con saldo
    Prestamo? destino = r.prestamoProximaCuota;
    destino ??= r.prestamos.isNotEmpty ? r.prestamos.first : null;
    if (destino == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrestamoDetalle(prestamoId: destino!.id!),
      ),
    );
    _cargar();
  }
}

class _Kpi {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  _Kpi(this.titulo, this.valor, this.icono, this.color);
}

class _ChipFiltro {
  final String id;
  final String label;
  final IconData icon;
  _ChipFiltro(this.id, this.label, this.icon);
}
