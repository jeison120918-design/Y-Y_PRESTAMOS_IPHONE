import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/cliente.dart';
import '../models/prestamista.dart';
import '../main.dart';

/// Formulario de cliente.
/// Ya NO se elige prestamista: se asigna automaticamente al unico prestamista
/// configurado en el telefono.
class ClienteForm extends StatefulWidget {
  final Cliente? cliente;
  const ClienteForm({super.key, this.cliente});

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _nombre, _cedula, _telefono, _direccion, _ref;
  Prestamista? _prestamista;
  bool _cargandoPrestamista = true;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _cedula = TextEditingController(text: c?.cedula ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _direccion = TextEditingController(text: c?.direccion ?? '');
    _ref = TextEditingController(text: c?.referencia ?? '');
    _cargarPrestamista();
  }

  Future<void> _cargarPrestamista() async {
    _prestamista = await DBHelper().getPrestamistaUnico();
    if (mounted) setState(() => _cargandoPrestamista = false);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_prestamista == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No hay prestamista configurado. Reinicia la app para completar la configuracion.')));
      return;
    }
    final c = Cliente(
      id: widget.cliente?.id,
      prestamistaId: _prestamista!.id!,
      nombre: _nombre.text.trim(),
      cedula: _cedula.text.trim(),
      telefono: _telefono.text.trim(),
      direccion: _direccion.text.trim(),
      referencia: _ref.text.trim(),
      fechaRegistro:
          widget.cliente?.fechaRegistro ?? DateTime.now().toIso8601String(),
    );
    if (c.id == null) {
      await DBHelper().insertCliente(c);
    } else {
      await DBHelper().updateCliente(c);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.cliente == null ? 'Nuevo Cliente' : 'Editar Cliente'),
      ),
      body: _cargandoPrestamista
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_prestamista != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AndryPrestamosApp.azulSuperficie,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AndryPrestamosApp.verdePrincipal),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin,
                              color: AndryPrestamosApp.verdePrincipal,
                              size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Prestamista',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                                Text(
                                  _prestamista!.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cedula,
                    decoration: const InputDecoration(
                      labelText: 'Cedula',
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefono',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccion,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Direccion',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ref,
                    decoration: const InputDecoration(
                      labelText: 'Referencia personal',
                      prefixIcon: Icon(Icons.contact_phone),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar cliente'),
                  ),
                ],
              ),
            ),
    );
  }
}
