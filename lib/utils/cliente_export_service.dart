import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import '../models/cliente.dart';
import '../models/prestamo.dart';
import '../models/cuota.dart';
import '../models/pago.dart';

/// Servicio para exportar e importar clientes específicos con el
/// progreso completo de sus préstamos (cuotas y pagos).
class ClienteExportService {
  static const String _version = '1.0';

  // ─── EXPORTAR ───────────────────────────────────────────────────────────────

  /// Exporta una lista de clientes (por ID) a un archivo .json y lo comparte.
  static Future<void> exportarClientes(
    List<int> clienteIds, {
    required void Function(String msg) onError,
    required void Function(String msg) onSuccess,
  }) async {
    try {
      final db = DBHelper();
      final List<Map<String, dynamic>> datosClientes = [];

      for (final cid in clienteIds) {
        final cliente = await db.getCliente(cid);
        if (cliente == null) continue;

        final prestamos = await db.getPrestamos(clienteId: cid);
        final List<Map<String, dynamic>> prestamosDatos = [];

        for (final prestamo in prestamos) {
          final cuotas = await db.getCuotas(prestamo.id!);
          final List<Map<String, dynamic>> cuotasDatos = [];

          for (final cuota in cuotas) {
            final pagos = await db.getPagosPorCuota(cuota.id!);
            cuotasDatos.add({
              'cuota': cuota.toMap(),
              'pagos': pagos.map((p) => p.toMap()).toList(),
            });
          }

          prestamosDatos.add({
            'prestamo': prestamo.toMap(),
            'cuotas': cuotasDatos,
          });
        }

        datosClientes.add({
          'cliente': cliente.toMap(),
          'prestamos': prestamosDatos,
        });
      }

      if (datosClientes.isEmpty) {
        onError('No se encontraron clientes para exportar.');
        return;
      }

      final exportData = {
        'version': _version,
        'app': 'yy_prestamos',
        'fecha_exportacion': DateTime.now().toIso8601String(),
        'total_clientes': datosClientes.length,
        'clientes': datosClientes,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      final bytes = utf8.encode(jsonStr);
      final ts = DateTime.now().millisecondsSinceEpoch;

      // XFile.fromData funciona igual en Web (dispara descarga / Web Share
      // API) y en Android/iOS, sin depender de un directorio temporal real.
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'clientes_yy_$ts.json',
            mimeType: 'application/json',
          )
        ],
        subject: 'Clientes Y&Y Prestamos',
        text:
            'Exportación de ${datosClientes.length} cliente(s) - ${DateTime.now().toString().substring(0, 10)}',
      );

      onSuccess(
          '${datosClientes.length} cliente(s) exportado(s) correctamente.');
    } catch (e) {
      onError('Error al exportar: $e');
    }
  }

  // ─── IMPORTAR ───────────────────────────────────────────────────────────────

  /// Resultado de importación para mostrar al usuario.
  static const _modoMerge =
      'merge'; // no duplica si ya existe mismo nombre+cedula
  static const _modoReemplazar =
      'reemplazar'; // elimina al existente y lo reimporta

  /// Abre el selector de archivos y devuelve el resultado del import.
  static Future<ImportResult> importarDesdeArchivo({
    String modo = _modoMerge,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelado();
    }

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      return ImportResult.error('No se pudo leer el archivo seleccionado.');
    }

    return _procesarImportacion(
      utf8.decode(bytes),
      modo: modo,
    );
  }

  static Future<ImportResult> _procesarImportacion(
    String jsonStr, {
    String modo = _modoMerge,
  }) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Backward-compatible: acepta backups del nombre anterior y del nuevo.
      final appTag = data['app'];
      if (appTag != 'yy_prestamos' && appTag != 'andry_prestamos') {
        return ImportResult.error(
            'El archivo no es un backup válido de Y&Y Prestamos.');
      }

      final clientes = data['clientes'] as List<dynamic>;
      if (clientes.isEmpty) {
        return ImportResult.error('El archivo no contiene clientes.');
      }

      final db = DBHelper();
      final prestamista = await db.getPrestamistaUnico();
      if (prestamista == null) {
        return ImportResult.error(
            'Configura tu perfil antes de importar clientes.');
      }

      int importados = 0;
      int omitidos = 0;
      final List<String> nombresImportados = [];

      for (final item in clientes) {
        final clienteMap = Map<String, dynamic>.from(item['cliente'] as Map);
        final prestamosData = item['prestamos'] as List<dynamic>;

        // Remapear al prestamista actual
        clienteMap.remove('id');
        clienteMap['prestamista_id'] = prestamista.id;

        // Verificar duplicado (mismo nombre + cédula)
        final existentes = await db.getClientes(prestamistaId: prestamista.id);
        final nombre = (clienteMap['nombre'] ?? '').toString().toLowerCase();
        final cedula = (clienteMap['cedula'] ?? '').toString();

        final yaExiste = existentes
            .any((c) => c.nombre.toLowerCase() == nombre && c.cedula == cedula);

        if (yaExiste && modo == _modoMerge) {
          omitidos++;
          continue;
        }

        // Insertar cliente
        final nuevoClienteId =
            await db.insertCliente(Cliente.fromMap(clienteMap));

        for (final pItem in prestamosData) {
          final prestamoMap =
              Map<String, dynamic>.from(pItem['prestamo'] as Map);
          final cuotasData = pItem['cuotas'] as List<dynamic>;

          final oldPrestamoId = prestamoMap['id'] as int?;
          prestamoMap.remove('id');
          prestamoMap['cliente_id'] = nuevoClienteId;

          // Insertar préstamo SIN registrar movimiento de capital doble.
          // Usamos insert directo para no duplicar movimientos.
          final sqliteDb = await db.database;
          final nuevoPrestamoId =
              await sqliteDb.insert('prestamos', prestamoMap);

          for (final cItem in cuotasData) {
            final cuotaMap = Map<String, dynamic>.from(cItem['cuota'] as Map);
            final pagosData = cItem['pagos'] as List<dynamic>;

            final oldCuotaId = cuotaMap['id'] as int?;
            cuotaMap.remove('id');
            cuotaMap['prestamo_id'] = nuevoPrestamoId;

            final nuevaCuotaId = await sqliteDb.insert('cuotas', cuotaMap);

            for (final pago in pagosData) {
              final pagoMap = Map<String, dynamic>.from(pago as Map);
              pagoMap.remove('id');
              pagoMap['cuota_id'] = nuevaCuotaId;
              // Insertar pago sin duplicar movimiento de capital
              await sqliteDb.insert('pagos', pagoMap);
            }
          }
        }

        importados++;
        nombresImportados.add(clienteMap['nombre'] ?? 'Sin nombre');
      }

      return ImportResult.exito(
        importados: importados,
        omitidos: omitidos,
        nombres: nombresImportados,
      );
    } catch (e) {
      return ImportResult.error('Error al procesar archivo: $e');
    }
  }
}

// ─── Modelo de resultado ────────────────────────────────────────────────────

enum ImportStatus { exito, error, cancelado }

class ImportResult {
  final ImportStatus status;
  final int importados;
  final int omitidos;
  final List<String> nombres;
  final String? mensajeError;

  ImportResult._({
    required this.status,
    this.importados = 0,
    this.omitidos = 0,
    this.nombres = const [],
    this.mensajeError,
  });

  factory ImportResult.exito({
    required int importados,
    required int omitidos,
    required List<String> nombres,
  }) =>
      ImportResult._(
        status: ImportStatus.exito,
        importados: importados,
        omitidos: omitidos,
        nombres: nombres,
      );

  factory ImportResult.error(String msg) => ImportResult._(
        status: ImportStatus.error,
        mensajeError: msg,
      );

  factory ImportResult.cancelado() =>
      ImportResult._(status: ImportStatus.cancelado);

  bool get esExito => status == ImportStatus.exito;
  bool get esError => status == ImportStatus.error;
  bool get esCancelado => status == ImportStatus.cancelado;
}
