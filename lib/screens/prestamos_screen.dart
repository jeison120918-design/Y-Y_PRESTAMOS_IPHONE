import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/prestamo.dart';
import '../models/cliente.dart';
import '../models/cuota.dart';
import '../utils/calculadora_penalidad.dart';
import '../utils/formato.dart';
import '../main.dart';
import 'prestamo_form.dart';
import 'prestamo_detalle.dart';

class PrestamosScreen extends StatefulWidget {
  final int? clienteId;
  final Cliente? cliente;
  const PrestamosScreen({super.key, this.clienteId, this.cliente});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  final _db = DBHelper();

  List<Prestamo> lista = [];
  Map<int, Cliente> _clientesMap = {};
  Map<int, List<Cuota>> _cuotasMap = {};
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => cargando = true);
    lista = await _db.getPrestamos(clienteId: widget.clienteId);
    final clientes = await _db.getClientes();
    _clientesMap = {for (final c in clientes) c.id!: c};
    _cuotasMap = await _db.getCuotasAgrupadasPorPrestamoIds(
      lista.map((p) => p.id!).whereType<int>(),
    );
    if (mounted) setState(() => cargando = false);
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return AndryPrestamosApp.verdePrincipal;
      case 'mora':
        return AndryPrestamosApp.rojoMora;
      default:
        return Colors.blue.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.cliente != null
        ? 'Prestamos de ${widget.cliente!.nombre}'
        : 'Mis Prestamos';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : lista.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_money_outlined,
                          size: 60, color: Colors.white30),
                      const SizedBox(height: 10),
                      const Text('No hay prestamos registrados.'),
                      const Text(
                        'Pulsa + para crear el primero.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: lista.length,
                    itemBuilder: (_, i) {
                      final p = lista[i];
                      final cliente = _clientesMap[p.clienteId];
                      final cuotas = _cuotasMap[p.id] ?? [];

                      final pendientes =
                          cuotas.where((c) => !c.estaPagada).length;
                      double saldo = 0;
                      double mora = 0;
                      for (final c in cuotas) {
                        if (!c.estaPagada) {
                          saldo += c.monto - c.montoPagado;
                          mora += calcularPenalidad(
                              c, p.modalidad, p.montoPenalidad);
                        }
                      }
                      final progreso = cuotas.isEmpty
                          ? 0.0
                          : cuotas.where((c) => c.estaPagada).length /
                              cuotas.length;
                      final color = _colorEstado(p.estado);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PrestamoDetalle(prestamoId: p.id!),
                                ),
                              );
                              _cargar();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            color.withOpacity(0.15),
                                        child: Icon(Icons.attach_money,
                                            color: color),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cliente?.nombre ??
                                                  'Cliente #${p.clienteId}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              'Prestamo #${p.id} · ${modalidadLabel(p.modalidad)}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white60),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          p.estado.toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _info('Capital',
                                            formatoMoneda(p.capital)),
                                      ),
                                      Expanded(
                                        child: _info('Total',
                                            formatoMoneda(p.montoTotal)),
                                      ),
                                      Expanded(
                                        child: _info('Cuotas',
                                            '${cuotas.length - pendientes}/${cuotas.length}'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progreso,
                                      minHeight: 6,
                                      backgroundColor:
                                          AndryPrestamosApp.azulSuperficieAlt,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Saldo: ${formatoMoneda(saldo)}',
                                          style: TextStyle(
                                            color: Colors.orange.shade400,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          )),
                                      if (mora > 0)
                                        Text('Mora: ${formatoMoneda(mora)}',
                                            style: const TextStyle(
                                              color: AndryPrestamosApp.rojoMora,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrestamoForm(clienteIdDefault: widget.clienteId),
            ),
          );
          _cargar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo prestamo'),
      ),
    );
  }

  Widget _info(String t, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        Text(v,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
