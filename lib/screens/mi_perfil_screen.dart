import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/prestamista.dart';
import '../main.dart';
import '../utils/formato.dart';

/// Pantalla del UNICO prestamista de la app.
/// Permite ver y editar los datos del dueno del telefono.
class MiPerfilScreen extends StatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  State<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends State<MiPerfilScreen> {
  Prestamista? prestamista;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    prestamista = await DBHelper().getPrestamistaUnico();
    if (mounted) setState(() => cargando = false);
  }

  Future<void> _editar() async {
    if (prestamista == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MiPerfilForm(prestamista: prestamista!),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : prestamista == null
              ? const Center(child: Text('No hay perfil configurado'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Tarjeta principal
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AndryPrestamosApp.azulOscuro,
                            AndryPrestamosApp.azulPrincipal,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AndryPrestamosApp.dorado,
                            child: Text(
                              prestamista!.nombre.isNotEmpty
                                  ? prestamista!.nombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AndryPrestamosApp.azulPrincipal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prestamista!.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Prestamista oficial',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  prestamista!.telefono.isEmpty
                                      ? 'Sin telefono'
                                      : prestamista!.telefono,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'INFORMACION',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white60,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _row(Icons.badge, 'Cedula', prestamista!.cedula),
                            _row(
                                Icons.phone, 'Telefono', prestamista!.telefono),
                            _row(Icons.location_on, 'Direccion',
                                prestamista!.direccion),
                            _row(Icons.account_balance, 'Capital inicial',
                                formatoMoneda(prestamista!.capitalInicial)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _editar,
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar mis datos'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AndryPrestamosApp.azulSuperficie,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade300, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Esta app está configurada para UN ÚNICO prestamista. '
                              'Todos los clientes que registres pertenecen a este perfil.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _row(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icono, color: AndryPrestamosApp.verdePrincipal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
                Text(
                  valor.isEmpty ? '-' : valor,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiPerfilForm extends StatefulWidget {
  final Prestamista prestamista;
  const _MiPerfilForm({required this.prestamista});

  @override
  State<_MiPerfilForm> createState() => _MiPerfilFormState();
}

class _MiPerfilFormState extends State<_MiPerfilForm> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _nombre, _cedula, _telefono, _direccion, _capital;

  @override
  void initState() {
    super.initState();
    final p = widget.prestamista;
    _nombre = TextEditingController(text: p.nombre);
    _cedula = TextEditingController(text: p.cedula);
    _telefono = TextEditingController(text: p.telefono);
    _direccion = TextEditingController(text: p.direccion);
    _capital = TextEditingController(text: p.capitalInicial.toString());
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final p = Prestamista(
      id: widget.prestamista.id,
      nombre: _nombre.text.trim(),
      cedula: _cedula.text.trim(),
      telefono: _telefono.text.trim(),
      direccion: _direccion.text.trim(),
      capitalInicial: double.tryParse(_capital.text) ?? 0,
      fechaRegistro: widget.prestamista.fechaRegistro,
    );
    await DBHelper().updatePrestamista(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _capital.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar mi perfil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              controller: _capital,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Capital inicial (RD\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
