import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/prestamista.dart';
import '../models/cliente.dart';
import '../models/prestamo.dart';
import '../models/cuota.dart';
import '../models/pago.dart';
import '../models/movimiento_capital.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    if (kIsWeb) {
      // En Web no existe sistema de archivos: sqflite_common_ffi_web guarda
      // la base de datos en IndexedDB del navegador (persiste entre sesiones
      // mientras el usuario no borre datos del sitio en Safari/Chrome).
      // Se usa la variante "sin Web Worker": corre sqlite3.wasm directo en el
      // hilo principal, sin depender de un Shared/Web Worker por separado.
      // Esto evita fallos de comunicación con el worker al desplegar en
      // hosting estático como GitHub Pages (más simple y estable para una
      // app de una sola pestaña como esta).
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      return await databaseFactory.openDatabase(
        'andry_prestamos.db',
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'andry_prestamos.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE prestamistas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        cedula TEXT,
        telefono TEXT,
        direccion TEXT,
        capital_inicial REAL DEFAULT 0,
        fecha_registro TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prestamista_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        cedula TEXT,
        telefono TEXT,
        direccion TEXT,
        referencia TEXT,
        fecha_registro TEXT,
        FOREIGN KEY(prestamista_id) REFERENCES prestamistas(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE prestamos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        capital REAL NOT NULL,
        tasa_interes REAL NOT NULL,
        monto_total REAL NOT NULL,
        modalidad TEXT NOT NULL,
        num_cuotas INTEGER NOT NULL,
        fecha_inicio TEXT NOT NULL,
        monto_penalidad REAL DEFAULT 0,
        estado TEXT DEFAULT 'activo',
        FOREIGN KEY(cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE cuotas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prestamo_id INTEGER NOT NULL,
        numero INTEGER NOT NULL,
        monto REAL NOT NULL,
        fecha_vencimiento TEXT NOT NULL,
        pagada INTEGER DEFAULT 0,
        monto_pagado REAL DEFAULT 0,
        fecha_pago TEXT,
        penalidad_aplicada REAL DEFAULT 0,
        FOREIGN KEY(prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE pagos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cuota_id INTEGER NOT NULL,
        monto REAL NOT NULL,
        penalidad REAL DEFAULT 0,
        fecha TEXT NOT NULL,
        observaciones TEXT,
        FOREIGN KEY(cuota_id) REFERENCES cuotas(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE movimientos_capital (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        descripcion TEXT,
        fecha TEXT NOT NULL,
        referencia_id INTEGER
      )
    ''');
    await _crearIndices(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movimientos_capital (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tipo TEXT NOT NULL,
          monto REAL NOT NULL,
          descripcion TEXT,
          fecha TEXT NOT NULL,
          referencia_id INTEGER
        )
      ''');
    }
    if (oldVersion < 4) {
      await _crearIndices(db);
    }
  }

  Future<void> _crearIndices(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clientes_prestamista_id ON clientes(prestamista_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_prestamos_cliente_id ON prestamos(cliente_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_prestamos_estado ON prestamos(estado)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cuotas_prestamo_id ON cuotas(prestamo_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cuotas_pagada_vencimiento ON cuotas(pagada, fecha_vencimiento)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pagos_cuota_id ON pagos(cuota_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_movimientos_tipo_fecha ON movimientos_capital(tipo, fecha)');
  }

  // ============ PRESTAMISTA ÚNICO ============
  Future<Prestamista?> getPrestamistaUnico() async {
    final db = await database;
    final res = await db.query('prestamistas', orderBy: 'id ASC', limit: 1);
    if (res.isEmpty) return null;
    return Prestamista.fromMap(res.first);
  }

  Future<bool> hayPrestamistaConfigurado() async {
    final p = await getPrestamistaUnico();
    return p != null;
  }

  Future<int> insertPrestamista(Prestamista p) async {
    final db = await database;
    final id = await db.insert('prestamistas', p.toMap());
    // Registrar capital inicial como movimiento
    if (p.capitalInicial > 0) {
      await insertMovimientoCapital(MovimientoCapital(
        tipo: 'inyeccion',
        monto: p.capitalInicial,
        descripcion: 'Capital inicial de apertura',
        fecha: p.fechaRegistro,
      ));
    }
    return id;
  }

  Future<int> updatePrestamista(Prestamista p) async {
    final db = await database;
    return await db
        .update('prestamistas', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  // ============ MOVIMIENTOS DE CAPITAL ============
  Future<int> insertMovimientoCapital(MovimientoCapital m) async {
    final db = await database;
    return await db.insert('movimientos_capital', m.toMap());
  }

  Future<List<MovimientoCapital>> getMovimientosCapital() async {
    final db = await database;
    final res = await db.query('movimientos_capital', orderBy: 'id DESC');
    return res.map((m) => MovimientoCapital.fromMap(m)).toList();
  }

  Future<double> getCapitalActual() async {
    final db = await database;
    // Capital = sum(movimientos: inyeccion/pago_recibido = +, retiro/prestamo_otorgado = -)
    // El capital inicial se registra como 'inyeccion' en movimientos_capital al crear prestamista.
    // Los pagos y préstamos se registran también como movimientos automáticamente.
    // Por tanto, la fórmula correcta es solo sumar/restar movimientos_capital.
    final r2 = await db.rawQuery('''
      SELECT
        IFNULL((SELECT SUM(CASE WHEN tipo='inyeccion' OR tipo='pago_recibido' THEN monto ELSE -monto END)
                FROM movimientos_capital), 0)
        AS capital_actual
    ''');
    final val = r2.first['capital_actual'];
    return val != null ? (val as num).toDouble() : 0.0;
  }

  Future<double> getCapitalEnPrestamos() async {
    final db = await database;
    final r = await db.rawQuery(
        "SELECT IFNULL(SUM(capital),0) AS total FROM prestamos WHERE estado != 'pagado'");
    return (r.first['total'] as num).toDouble();
  }

  Future<Map<String, num>> getHomeStats() async {
    final db = await database;
    final r = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM clientes) AS total_clientes,
        (SELECT COUNT(*) FROM prestamos) AS total_prestamos,
        IFNULL((SELECT SUM(CASE WHEN tipo='inyeccion' OR tipo='pago_recibido' THEN monto ELSE -monto END)
                FROM movimientos_capital), 0) AS capital_actual,
        IFNULL((SELECT SUM(capital) FROM prestamos WHERE estado != 'pagado'), 0) AS capital_en_prestamos,
        IFNULL((SELECT SUM(monto + penalidad) FROM pagos), 0) AS total_cobrado
    ''');
    final row = r.first;
    return {
      'totalClientes': (row['total_clientes'] as num?) ?? 0,
      'totalPrestamos': (row['total_prestamos'] as num?) ?? 0,
      'capitalActual': (row['capital_actual'] as num?) ?? 0,
      'capitalEnPrestamos': (row['capital_en_prestamos'] as num?) ?? 0,
      'totalCobrado': (row['total_cobrado'] as num?) ?? 0,
    };
  }

  // ============ CLIENTES ============
  Future<int> insertCliente(Cliente c) async {
    final db = await database;
    return await db.insert('clientes', c.toMap());
  }

  Future<List<Cliente>> getClientes({int? prestamistaId}) async {
    final db = await database;
    final res = prestamistaId == null
        ? await db.query('clientes', orderBy: 'nombre')
        : await db.query('clientes',
            where: 'prestamista_id = ?',
            whereArgs: [prestamistaId],
            orderBy: 'nombre');
    return res.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<Cliente?> getCliente(int id) async {
    final db = await database;
    final res = await db.query('clientes', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Cliente.fromMap(res.first);
  }

  Future<int> updateCliente(Cliente c) async {
    final db = await database;
    return await db
        .update('clientes', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteCliente(int id) async {
    final db = await database;
    return await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  // ============ PRESTAMOS ============
  Future<int> insertPrestamo(Prestamo p) async {
    final db = await database;
    final id = await db.insert('prestamos', p.toMap());
    // Registrar salida de capital
    await insertMovimientoCapital(MovimientoCapital(
      tipo: 'prestamo_otorgado',
      monto: p.capital,
      descripcion: 'Préstamo otorgado #$id',
      fecha: p.fechaInicio,
      referenciaId: id,
    ));
    return id;
  }

  Future<List<Prestamo>> getPrestamos({int? clienteId}) async {
    final db = await database;
    final res = clienteId == null
        ? await db.query('prestamos', orderBy: 'id DESC')
        : await db.query('prestamos',
            where: 'cliente_id = ?',
            whereArgs: [clienteId],
            orderBy: 'id DESC');
    return res.map((m) => Prestamo.fromMap(m)).toList();
  }

  Future<Prestamo?> getPrestamo(int id) async {
    final db = await database;
    final res = await db.query('prestamos', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Prestamo.fromMap(res.first);
  }

  Future<int> updatePrestamo(Prestamo p) async {
    final db = await database;
    return await db
        .update('prestamos', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deletePrestamo(int id) async {
    final db = await database;
    return await db.delete('prestamos', where: 'id = ?', whereArgs: [id]);
  }

  // ============ CUOTAS ============
  Future<int> insertCuota(Cuota c) async {
    final db = await database;
    return await db.insert('cuotas', c.toMap());
  }

  Future<void> insertCuotasBatch(List<Cuota> cuotas) async {
    final db = await database;
    final batch = db.batch();
    for (final c in cuotas) {
      batch.insert('cuotas', c.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Cuota>> getCuotas(int prestamoId) async {
    final db = await database;
    final res = await db.query('cuotas',
        where: 'prestamo_id = ?',
        whereArgs: [prestamoId],
        orderBy: 'numero ASC');
    return res.map((m) => Cuota.fromMap(m)).toList();
  }

  Future<Cuota?> getCuota(int id) async {
    final db = await database;
    final res = await db.query('cuotas', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Cuota.fromMap(res.first);
  }

  Future<int> updateCuota(Cuota c) async {
    final db = await database;
    return await db
        .update('cuotas', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<List<Cuota>> getTodasLasCuotas() async {
    final db = await database;
    final res = await db.query('cuotas', orderBy: 'fecha_vencimiento ASC');
    return res.map((m) => Cuota.fromMap(m)).toList();
  }

  Future<Map<int, List<Cuota>>> getCuotasAgrupadasPorPrestamoIds(
      Iterable<int> prestamoIds) async {
    final ids = prestamoIds.toSet().toList()..sort();
    if (ids.isEmpty) return {};

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final res = await db.query(
      'cuotas',
      where: 'prestamo_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'prestamo_id ASC, numero ASC',
    );

    final agrupadas = <int, List<Cuota>>{};
    for (final row in res) {
      final cuota = Cuota.fromMap(row);
      (agrupadas[cuota.prestamoId] ??= []).add(cuota);
    }
    return agrupadas;
  }

  // ============ PAGOS ============
  Future<int> insertPago(Pago p) async {
    final db = await database;
    final id = await db.insert('pagos', p.toMap());
    // Registrar entrada de capital por pago
    await insertMovimientoCapital(MovimientoCapital(
      tipo: 'pago_recibido',
      monto: p.monto + p.penalidad,
      descripcion: 'Pago recibido cuota #${p.cuotaId}',
      fecha: p.fecha,
      referenciaId: p.cuotaId,
    ));
    return id;
  }

  Future<List<Pago>> getPagosPorCuota(int cuotaId) async {
    final db = await database;
    final res = await db.query('pagos',
        where: 'cuota_id = ?', whereArgs: [cuotaId], orderBy: 'id DESC');
    return res.map((m) => Pago.fromMap(m)).toList();
  }

  Future<List<Pago>> getTodosLosPagos() async {
    final db = await database;
    final res = await db.query('pagos', orderBy: 'fecha DESC');
    return res.map((m) => Pago.fromMap(m)).toList();
  }

  // ============ DASHBOARD ============
  Future<double> sumarCapitalActivo() async {
    return await getCapitalEnPrestamos();
  }

  Future<double> sumarTotalCobrado() async {
    final db = await database;
    final r = await db.rawQuery(
        "SELECT IFNULL(SUM(monto + penalidad),0) AS total FROM pagos");
    return (r.first['total'] as num).toDouble();
  }

  Future<double> sumarPendiente() async {
    final db = await database;
    final r = await db.rawQuery(
        "SELECT IFNULL(SUM(monto - monto_pagado),0) AS total FROM cuotas WHERE pagada = 0");
    return (r.first['total'] as num).toDouble();
  }

  Future<int> contarCuotasVencidasHoy() async {
    final db = await database;
    final hoyStr = _ymd(DateTime.now());
    final r = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM cuotas WHERE pagada = 0 AND fecha_vencimiento = ?",
        [hoyStr]);
    return (r.first['c'] as int);
  }

  Future<int> contarCuotasEnMora() async {
    final db = await database;
    final hoyStr = _ymd(DateTime.now());
    final r = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM cuotas WHERE pagada = 0 AND fecha_vencimiento < ?",
        [hoyStr]);
    return (r.first['c'] as int);
  }

  String _ymd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Ruta del archivo físico .db. Solo válido en Android/iOS/Desktop.
  /// En Web la base vive dentro de IndexedDB y no existe un archivo real,
  /// por eso este método lanza [UnsupportedError]: la UI debe comprobar
  /// `kIsWeb` antes de llamarlo (ver `configuracion_screen.dart`, que en Web
  /// oculta el botón "Backup completo .db" y ofrece en su lugar la
  /// exportación JSON de clientes, que sí funciona igual en todas las
  /// plataformas).
  Future<String> getDbPath() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'No hay archivo .db en Web (la base vive en IndexedDB). '
          'Usa la exportación JSON de clientes como respaldo.');
    }
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'andry_prestamos.db');
  }

  Future<File> exportarDB(String destino) async {
    final origen = await getDbPath();
    return await File(origen).copy(destino);
  }
}
