import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../main.dart';
import '../models/prestamista.dart';
import 'home_screen.dart';

/// Pantalla de configuracion inicial: el unico prestamista del telefono.
/// Solo se muestra UNA VEZ. Despues queda fijo (editable desde "Mi Perfil").
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _cedula = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _capital = TextEditingController(text: '0');
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final p = Prestamista(
      nombre: _nombre.text.trim(),
      cedula: _cedula.text.trim(),
      telefono: _telefono.text.trim(),
      direccion: _direccion.text.trim(),
      capitalInicial: double.tryParse(_capital.text) ?? 0,
      fechaRegistro: DateTime.now().toIso8601String(),
    );
    await DBHelper().insertPrestamista(p);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Cabecera con gradiente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AndryPrestamosApp.azulOscuro,
                      AndryPrestamosApp.azulPrincipal,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: AndryPrestamosApp.dorado,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_pin,
                          color: AndryPrestamosApp.azulPrincipal, size: 56),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Bienvenido a Y&Y Prestamos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Configura los datos del prestamista de este telefono.\n'
                      'Esta informacion solo se registra UNA VEZ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos del prestamista',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AndryPrestamosApp.verdeClaro,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
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
                          labelText: 'Telefono *',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Capital inicial (RD\$)',
                          prefixIcon: Icon(Icons.attach_money),
                          helperText: 'Monto con el que inicias tu negocio',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _guardando ? null : _guardar,
                          icon: _guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(_guardando
                              ? 'Guardando...'
                              : 'Comenzar a usar Y&Y Prestamos'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AndryPrestamosApp.dorado.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AndryPrestamosApp.dorado.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline,
                                color: AndryPrestamosApp.dorado),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Esta app esta disenada para UN UNICO prestamista por '
                                'dispositivo. Los datos quedan guardados en este telefono.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'IMPORTANTE: para que tus datos NO se borren, '
                                  'agrega esta app a tu pantalla de inicio '
                                  '(Compartir > Agregar a pantalla de inicio) y '
                                  'usala siempre desde ese icono, no desde Safari.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
