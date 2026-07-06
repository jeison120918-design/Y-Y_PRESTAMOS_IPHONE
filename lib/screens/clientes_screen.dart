import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/db_helper.dart';
import '../models/cliente.dart';
import '../main.dart';
import 'cliente_form.dart';
import 'prestamos_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> lista = [];
  List<Cliente> filtrada = [];
  bool cargando = true;
  final _busqueda = TextEditingController();
  Timer? _busquedaDebounce;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    lista = await DBHelper().getClientes();
    filtrada = lista;
    if (mounted) setState(() => cargando = false);
  }

  void _filtrar(String q) {
    _busquedaDebounce?.cancel();
    _busquedaDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final ql = q.toLowerCase().trim();
      setState(() {
        filtrada = ql.isEmpty
            ? lista
            : lista
                .where((c) =>
                    c.nombre.toLowerCase().contains(ql) ||
                    c.cedula.toLowerCase().contains(ql) ||
                    c.telefono.toLowerCase().contains(ql))
                .toList();
      });
    });
  }

  Future<void> _eliminar(Cliente c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
            'Se eliminara ${c.nombre} y TODOS sus prestamos y pagos. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await DBHelper().deleteCliente(c.id!);
      _cargar();
    }
  }

  Future<void> _llamar(String telefono) async {
    if (telefono.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: telefono);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _busquedaDebounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _busqueda,
              onChanged: _filtrar,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, cedula o telefono',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : filtrada.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 60, color: Colors.white30),
                            const SizedBox(height: 10),
                            const Text('No hay clientes registrados.'),
                            const SizedBox(height: 4),
                            const Text(
                              'Pulsa + para agregar tu primer cliente.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtrada.length,
                        itemBuilder: (_, i) {
                          final c = filtrada[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PrestamosScreen(
                                          clienteId: c.id, cliente: c),
                                    ),
                                  );
                                  _cargar();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AndryPrestamosApp
                                            .azulClaro
                                            .withOpacity(0.20),
                                        child: Text(
                                          c.nombre.isNotEmpty
                                              ? c.nombre[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color:
                                                AndryPrestamosApp.azulPrincipal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if (c.cedula.isNotEmpty)
                                              Text('Cedula: ${c.cedula}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white60)),
                                            if (c.telefono.isNotEmpty)
                                              Text('Tel: ${c.telefono}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white60)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (v) async {
                                          if (v == 'prestamos') {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PrestamosScreen(
                                                    clienteId: c.id,
                                                    cliente: c),
                                              ),
                                            );
                                            _cargar();
                                          } else if (v == 'llamar') {
                                            _llamar(c.telefono);
                                          } else if (v == 'editar') {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ClienteForm(cliente: c),
                                              ),
                                            );
                                            _cargar();
                                          } else if (v == 'eliminar') {
                                            _eliminar(c);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'prestamos',
                                            child: ListTile(
                                              leading: Icon(Icons.attach_money,
                                                  color: AndryPrestamosApp
                                                      .verdePrincipal),
                                              title: Text('Ver prestamos'),
                                              dense: true,
                                            ),
                                          ),
                                          if (c.telefono.isNotEmpty)
                                            const PopupMenuItem(
                                              value: 'llamar',
                                              child: ListTile(
                                                leading: Icon(Icons.phone,
                                                    color: Colors.blue),
                                                title: Text('Llamar'),
                                                dense: true,
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'editar',
                                            child: ListTile(
                                              leading: Icon(Icons.edit,
                                                  color: Colors.blueGrey),
                                              title: Text('Editar'),
                                              dense: true,
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'eliminar',
                                            child: ListTile(
                                              leading: Icon(Icons.delete,
                                                  color: Colors.red),
                                              title: Text('Eliminar'),
                                              dense: true,
                                            ),
                                          ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClienteForm()),
          );
          _cargar();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cliente'),
      ),
    );
  }
}
