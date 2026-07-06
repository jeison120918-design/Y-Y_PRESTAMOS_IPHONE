import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/prestamista.dart';
import '../models/movimiento_capital.dart';
import '../main.dart';
import 'clientes_screen.dart';
import 'prestamos_screen.dart';
import 'dashboard_screen.dart';
import 'configuracion_screen.dart';
import 'mi_perfil_screen.dart';
import 'capital_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _db = DBHelper();

  Prestamista? prestamista;
  int totalClientes = 0;
  int totalPrestamos = 0;
  double capitalActual = 0;
  double capitalEnPrestamos = 0;
  double totalCobrado = 0;
  bool _cargando = true;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _cargar();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    prestamista = await _db.getPrestamistaUnico();
    final stats = await _db.getHomeStats();
    capitalActual = (stats['capitalActual'] ?? 0).toDouble();
    capitalEnPrestamos = (stats['capitalEnPrestamos'] ?? 0).toDouble();
    totalCobrado = (stats['totalCobrado'] ?? 0).toDouble();
    totalClientes = (stats['totalClientes'] ?? 0).toInt();
    totalPrestamos = (stats['totalPrestamos'] ?? 0).toInt();
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = prestamista?.nombre ?? 'Prestamista';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AndryPrestamosApp.azulOscuro,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          color: AndryPrestamosApp.dorado,
          backgroundColor: AndryPrestamosApp.azulSuperficie,
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AndryPrestamosApp.dorado))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeader(nombre, inicial),
                    _buildCapitalCard(),
                    _buildStatsRow(),
                    _buildSectionTitle('ACCESOS RÁPIDOS'),
                    _buildMenuGrid(),
                    _buildCapitalActions(),
                    _buildFooter(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(String nombre, String inicial) {
    return Container(
      decoration: const BoxDecoration(
        color: AndryPrestamosApp.azulOscuro,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MiPerfilScreen()));
              _cargar();
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    AndryPrestamosApp.dorado,
                    AndryPrestamosApp.doradoOscuro
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AndryPrestamosApp.dorado.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Center(
                child: Text(inicial,
                    style: const TextStyle(
                      color: AndryPrestamosApp.azulOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    )),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenido de nuevo',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text(nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _headerBtn(Icons.settings_outlined, Colors.white70, () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ConfiguracionScreen()));
          }),
        ],
      ),
    );
  }

  Widget _headerBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildCapitalCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AndryPrestamosApp.azulPrincipal,
            AndryPrestamosApp.azulProfundo,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AndryPrestamosApp.azulPrincipal.withOpacity(0.45),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(AndryPrestamosApp.dorado, Colors.white,
                        _pulseCtrl.value),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('CAPITAL DISPONIBLE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CapitalScreen()));
                  _cargar();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.history, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Historial',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _fmt(capitalActual),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RD\$ en caja disponible',
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _capitalMini(
                Icons.trending_up,
                'En Préstamos',
                _fmt(capitalEnPrestamos),
                AndryPrestamosApp.dorado,
              ),
              const SizedBox(width: 12),
              _capitalMini(
                Icons.check_circle_outline,
                'Total Cobrado',
                _fmt(totalCobrado),
                AndryPrestamosApp.verdeClaro,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _capitalMini(IconData icon, String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text(val,
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _statChip(Icons.people_alt, '$totalClientes', 'Clientes',
              AndryPrestamosApp.azulInfo),
          const SizedBox(width: 10),
          _statChip(Icons.receipt_long, '$totalPrestamos', 'Préstamos',
              AndryPrestamosApp.verdePrincipal),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AndryPrestamosApp.azulSuperficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Text(title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          )),
    );
  }

  Widget _buildMenuGrid() {
    // NOTA: PrestamosScreen NO puede ser const cuando se instancia sin
    // clienteId (el StatefulWidget muta su estado interno). Se instancia
    // en tiempo de ejecución sin argumentos.
    final items = <_MenuItem>[
      _MenuItem('Dashboard', 'Resumen y alertas', Icons.dashboard_rounded,
          AndryPrestamosApp.azulInfo, const DashboardScreen()),
      _MenuItem('Clientes', 'Gestionar deudores', Icons.people_alt_rounded,
          AndryPrestamosApp.azulClaro, const ClientesScreen()),
      _MenuItem('Préstamos', 'Crear y gestionar', Icons.attach_money_rounded,
          AndryPrestamosApp.verdePrincipal, const PrestamosScreen()),
      _MenuItem('Mi Perfil', 'Datos del negocio', Icons.person_pin_rounded,
          AndryPrestamosApp.dorado, const MiPerfilScreen()),
      _MenuItem('Capital', 'Inyectar / Retirar', Icons.account_balance_wallet,
          AndryPrestamosApp.verdeClaro, const CapitalScreen()),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildMenuTile(items[i]),
      ),
    );
  }

  Widget _buildMenuTile(_MenuItem item) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => item.screen));
        _cargar();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AndryPrestamosApp.azulSuperficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: item.color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(item.titulo,
                style: TextStyle(
                    color: item.color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            Text(item.sub,
                style: const TextStyle(color: Colors.white54, fontSize: 9),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalActions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AndryPrestamosApp.azulSuperficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACCIONES DE CAPITAL',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _accionCapital(
                  Icons.add_circle_outline,
                  'Inyectar',
                  AndryPrestamosApp.verdePrincipal,
                  () => _mostrarDialogoCapital(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _accionCapital(
                  Icons.remove_circle_outline,
                  'Retirar',
                  AndryPrestamosApp.rojoRetiro,
                  () => _mostrarDialogoCapital(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _accionCapital(
                  Icons.picture_as_pdf,
                  'Estado',
                  AndryPrestamosApp.dorado,
                  () => _verEstadoGeneral(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accionCapital(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        children: [
          Text(
            'Y&Y Préstamos · ${AndryPrestamosApp.telefonoDueno}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by ${AndryPrestamosApp.creadorFirma}',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoCapital(bool esInyeccion) async {
    final ctrl = TextEditingController();
    final descCtrl = TextEditingController();
    final color = esInyeccion
        ? AndryPrestamosApp.verdePrincipal
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    esInyeccion
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    color: color,
                    size: 32),
              ),
              const SizedBox(height: 14),
              Text(titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              TextField(
                controller: ctrl,
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
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  void _verEstadoGeneral() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const CapitalScreen(mostrarEstado: true)));
    _cargar();
  }

  String _fmt(double val) {
    final abs = val.abs();
    String s;
    if (abs >= 1000000) {
      s = '${(abs / 1000000).toStringAsFixed(2)}M';
    } else if (abs >= 1000) {
      final parts = abs.toStringAsFixed(2).split('.');
      final entero = parts[0];
      final dec = parts[1];
      String formatted = '';
      for (int i = 0; i < entero.length; i++) {
        if (i > 0 && (entero.length - i) % 3 == 0) formatted += ',';
        formatted += entero[i];
      }
      s = '$formatted.$dec';
    } else {
      s = abs.toStringAsFixed(2);
    }
    return 'RD\$ ${val < 0 ? "-" : ""}$s';
  }
}

class _MenuItem {
  final String titulo;
  final String sub;
  final IconData icon;
  final Color color;
  final Widget screen;
  _MenuItem(this.titulo, this.sub, this.icon, this.color, this.screen);
}
