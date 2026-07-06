import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../database/db_helper.dart';
import '../models/prestamista.dart';
import '../models/cliente.dart';
import '../main.dart';
import '../utils/cliente_export_service.dart';
import 'mi_perfil_screen.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  Prestamista? prestamista;
  bool _loadingExport = false;
  bool _loadingImport = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    prestamista = await DBHelper().getPrestamistaUnico();
    if (mounted) setState(() {});
  }

  // ── Backup completo de la BD ──────────────────────────────────────────────
  // Solo aplica fuera de Web (ver ListTile condicional más abajo). Lee el
  // archivo .db nativo en bytes y lo comparte sin depender de una ruta de
  // archivo temporal escrita manualmente (más simple y también funciona en
  // iOS/Android si el proyecto se compila como app nativa en el futuro).
  Future<void> _exportarBackupCompleto() async {
    try {
      final origen = await DBHelper().getDbPath();
      final bytes = await File(origen).readAsBytes();
      final nombre = 'backup_yy_${DateTime.now().millisecondsSinceEpoch}.db';
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: nombre, mimeType: 'application/x-sqlite3')],
        text: 'Backup completo Y&Y Prestamos',
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error al exportar backup: $e');
    }
  }

  // ── Exportar clientes específicos ─────────────────────────────────────────
  Future<void> _exportarClientesEspecificos() async {
    final clientes =
        await DBHelper().getClientes(prestamistaId: prestamista?.id);

    if (clientes.isEmpty) {
      if (!mounted) return;
      _mostrarError('No hay clientes registrados.');
      return;
    }

    // Mostrar selector de clientes
    if (!mounted) return;
    final seleccionados = await showDialog<List<int>>(
      context: context,
      builder: (_) => _SelectorClientesDialog(clientes: clientes),
    );

    if (seleccionados == null || seleccionados.isEmpty) return;

    setState(() => _loadingExport = true);
    await ClienteExportService.exportarClientes(
      seleccionados,
      onError: (msg) {
        if (mounted) _mostrarError(msg);
      },
      onSuccess: (msg) {
        if (mounted) _mostrarExito(msg);
      },
    );
    if (mounted) setState(() => _loadingExport = false);
  }

  // ── Importar clientes desde archivo JSON ──────────────────────────────────
  Future<void> _importarClientes() async {
    // Preguntar modo (merge o reemplazar)
    if (!mounted) return;
    final modo = await showDialog<String>(
      context: context,
      builder: (_) => const _ModoImportDialog(),
    );
    if (modo == null) return;

    setState(() => _loadingImport = true);
    final result = await ClienteExportService.importarDesdeArchivo(modo: modo);
    if (!mounted) {
      setState(() => _loadingImport = false);
      return;
    }
    setState(() => _loadingImport = false);

    if (result.esCancelado) return;

    if (result.esError) {
      _mostrarError(result.mensajeError ?? 'Error desconocido');
      return;
    }

    // Éxito
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AndryPrestamosApp.azulSuperficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AndryPrestamosApp.verdeClaro),
            const SizedBox(width: 8),
            const Text('Importación exitosa',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Clientes importados', '${result.importados}'),
            if (result.omitidos > 0)
              _infoRow('Omitidos (ya existían)', '${result.omitidos}'),
            if (result.nombres.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Clientes importados:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 6),
              ...result.nombres.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.person,
                            color: AndryPrestamosApp.verdeClaro, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(n,
                                style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  )),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar',
                style: TextStyle(color: Color(0xFFFFC107))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(val,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: AndryPrestamosApp.rojoMora,
    ));
  }

  void _mostrarExito(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: AndryPrestamosApp.azulPrincipal,
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AndryPrestamosApp.azulOscuro,
                  AndryPrestamosApp.azulPrincipal,
                ],
              ),
            ),
            child: Column(
              children: [
                Image.asset(
                  AndryPrestamosApp.logoAsset,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_wallet,
                      color: AndryPrestamosApp.dorado,
                      size: 50),
                ),
                const SizedBox(height: 8),
                const Text('Y&Y PRESTAMOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 2,
                    )),
                const SizedBox(height: 4),
                const Text('Sistema de Control de Préstamos',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Versión ${AndryPrestamosApp.versionApp}',
                    style: TextStyle(color: Colors.white.withOpacity(0.6))),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Perfil
          ListTile(
            leading: const Icon(Icons.person_pin,
                color: AndryPrestamosApp.verdePrincipal),
            title: const Text('Mi Perfil'),
            subtitle: Text(prestamista?.nombre ?? 'No configurado',
                style: const TextStyle(color: Colors.white60)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MiPerfilScreen()));
              _cargar();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.blue),
            title: const Text('Teléfono del prestamista'),
            subtitle: Text(
                prestamista?.telefono ?? AndryPrestamosApp.telefonoDueno,
                style: const TextStyle(color: Colors.white60)),
          ),
          const ListTile(
            leading:
                Icon(Icons.attach_money, color: AndryPrestamosApp.azulClaro),
            title: Text('Moneda'),
            subtitle: Text('Peso Dominicano (RD\$)',
                style: TextStyle(color: Colors.white60)),
          ),
          const Divider(),

          // ─── AVISO CRITICO: instalar en pantalla de inicio (solo Web) ─────
          // Esta es la unica accion que realmente evita que Safari/iOS borre
          // los datos por inactividad del sitio. Ningun codigo puede forzarla,
          // solo recordarsela al usuario.
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Text('IMPORTANTE: no pierdas tus datos',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Para que Safari/iPhone NO borre la informacion de esta app:\n\n'
                      '1. Toca el boton "Compartir" (cuadro con flecha) en Safari.\n'
                      '2. Elige "Agregar a pantalla de inicio".\n'
                      '3. Usa siempre el icono desde la pantalla de inicio, no una '
                      'pestaña de Safari.\n\n'
                      'Ademas, exporta un respaldo (JSON) al menos una vez por semana '
                      'desde la seccion de abajo, por seguridad.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

          // ─── SECCIÓN BACKUP / EXPORTACIÓN ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('RESPALDO Y TRANSFERENCIA',
                style: TextStyle(
                    color: AndryPrestamosApp.dorado,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ),

          // Backup completo (.db) — solo disponible fuera de Web, porque en
          // el navegador la base vive en IndexedDB y no existe un archivo
          // físico que copiar. En Web se recomienda "Exportar clientes"
          // (JSON) como respaldo, que funciona igual en todas las plataformas.
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.blue),
              title: const Text('Exportar backup completo'),
              subtitle: const Text('Toda la información (.db)',
                  style: TextStyle(color: Colors.white60)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportarBackupCompleto,
            )
          else
            const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.white38),
              title: Text('Backup completo (.db)'),
              subtitle: Text(
                  'No disponible en la versión Web. Usa "Exportar clientes" '
                  'de abajo como respaldo.',
                  style: TextStyle(color: Colors.white60)),
            ),
          const Divider(indent: 16, endIndent: 16),

          // Exportar clientes específicos
          ListTile(
            leading: _loadingExport
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AndryPrestamosApp.verdePrincipal))
                : const Icon(Icons.person_add_alt_1,
                    color: AndryPrestamosApp.verdePrincipal),
            title: const Text('Exportar clientes específicos'),
            subtitle: const Text(
                'Selecciona clientes con sus préstamos y pagos para enviar a otro dispositivo',
                style: TextStyle(color: Colors.white60)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _loadingExport ? null : _exportarClientesEspecificos,
          ),
          const Divider(indent: 16, endIndent: 16),

          // Importar clientes
          ListTile(
            leading: _loadingImport
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AndryPrestamosApp.dorado))
                : const Icon(Icons.file_upload_outlined,
                    color: AndryPrestamosApp.dorado),
            title: const Text('Importar clientes'),
            subtitle: const Text(
                'Carga un archivo .json de clientes exportado desde otro dispositivo',
                style: TextStyle(color: Colors.white60)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _loadingImport ? null : _importarClientes,
          ),
          const Divider(),

          // ─── INFO ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AndryPrestamosApp.azulSuperficieAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AndryPrestamosApp.verdePrincipal.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AndryPrestamosApp.dorado),
                      const SizedBox(width: 8),
                      const Text('Acerca de la app',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Y&Y Préstamos es un sistema OFFLINE para un solo prestamista por teléfono. '
                    'Toda la información se guarda en este dispositivo.\n\n'
                    'Modalidades soportadas: Diaria, Semanal, Quincenal (cada 15 días) y Mensual.\n\n'
                    'La penalidad se aplica como RÉDITO DIARIO PRORRATEADO. '
                    'Si un cliente paga antes de completar el periodo (semana, quincena o mes), '
                    'solo se cobra la fracción de días transcurridos desde el vencimiento.\n\n'
                    '✅ Exporta clientes específicos para enviarlos a otro dispositivo con el mismo sistema.\n'
                    '✅ Recuerda exportar backup periódicamente.',
                    style: TextStyle(
                        color: Colors.white, height: 1.6, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Soporte
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AndryPrestamosApp.azulSuperficieAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.headset_mic,
                      color: AndryPrestamosApp.verdePrincipal, size: 20),
                  const SizedBox(width: 10),
                  const Text('Soporte: ',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Text('829-796-4283',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Marca del creador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AndryPrestamosApp.azulPrincipal.withOpacity(0.95),
                    AndryPrestamosApp.verdePrincipal.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.code,
                      color: AndryPrestamosApp.dorado, size: 22),
                  const SizedBox(height: 6),
                  const Text('Sistema desarrollado por',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(AndryPrestamosApp.creadorSistema,
                      style: const TextStyle(
                        color: AndryPrestamosApp.dorado,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      )),
                  Text('Tel: ${AndryPrestamosApp.creadorTelefono}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Diálogo selector de clientes ─────────────────────────────────────────
class _SelectorClientesDialog extends StatefulWidget {
  final List<Cliente> clientes;
  const _SelectorClientesDialog({required this.clientes});

  @override
  State<_SelectorClientesDialog> createState() =>
      _SelectorClientesDialogState();
}

class _SelectorClientesDialogState extends State<_SelectorClientesDialog> {
  final Set<int> _seleccionados = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AndryPrestamosApp.azulSuperficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Seleccionar clientes',
          style: TextStyle(color: Colors.white, fontSize: 17)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botones de todos/ninguno
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() =>
                      _seleccionados.addAll(widget.clientes.map((c) => c.id!))),
                  child: const Text('Todos',
                      style: TextStyle(color: AndryPrestamosApp.dorado)),
                ),
                TextButton(
                  onPressed: () => setState(() => _seleccionados.clear()),
                  child: const Text('Ninguno',
                      style: TextStyle(color: Colors.white54)),
                ),
                const Spacer(),
                Text('${_seleccionados.length} sel.',
                    style: const TextStyle(color: Colors.white60)),
              ],
            ),
            const Divider(color: Colors.white12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.clientes.length,
                itemBuilder: (_, i) {
                  final c = widget.clientes[i];
                  final sel = _seleccionados.contains(c.id);
                  return CheckboxListTile(
                    value: sel,
                    activeColor: AndryPrestamosApp.verdePrincipal,
                    checkColor: Colors.white,
                    onChanged: (v) => setState(() => v == true
                        ? _seleccionados.add(c.id!)
                        : _seleccionados.remove(c.id)),
                    title: Text(c.nombre,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: c.cedula.isNotEmpty
                        ? Text(c.cedula,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12))
                        : null,
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          onPressed: _seleccionados.isEmpty
              ? null
              : () => Navigator.pop(context, _seleccionados.toList()),
          icon: const Icon(Icons.share, size: 18),
          label: Text('Exportar (${_seleccionados.length})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AndryPrestamosApp.verdePrincipal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─── Diálogo modo de importación ──────────────────────────────────────────
class _ModoImportDialog extends StatelessWidget {
  const _ModoImportDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AndryPrestamosApp.azulSuperficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.file_upload_outlined, color: AndryPrestamosApp.dorado),
          SizedBox(width: 8),
          Text('Importar clientes',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ],
      ),
      content: const Text(
        '¿Cómo deseas manejar clientes que ya existen en este dispositivo?',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white38)),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'merge'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
          ),
          child: const Text('Omitir duplicados'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'reemplazar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AndryPrestamosApp.verdePrincipal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Importar todo'),
        ),
      ],
    );
  }
}
