import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Conexion {
  static final String nameDB = 'Despensa';
  static final int version = 4;

  static Database? _database;

  Future<Database?> get database async {
    if (_database != null) return _database;
    return _database = await _initDataBase();
  }

  Future<Database> _initDataBase() async {
    final Directory folder = await getApplicationDocumentsDirectory();
    final String pathDb = join(folder.path, nameDB);

    return openDatabase(
      pathDb,
      version: version,
      onCreate: createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migración de la versión 1 a la versión 2.
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE lote '
            'ADD COLUMN cantidad_inicial INTEGER NOT NULL DEFAULT 0',
          );

          await db.execute(
            'UPDATE lote SET cantidad_inicial = cantidad',
          );
        }

        // Migración de la versión 2 a la versión 3.
        if (oldVersion < 3) {
          await _crearTablaMovimientos(db);
        }

        // Migración de la versión 3 a la versión 4.
        if (oldVersion < 4) {
          await _crearTablaCarrito(db);
        }
      },
    );
  }

  Future<void> createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categoria(
        id INTEGER PRIMARY KEY,
        nombre TEXT,
        descripcion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tienda(
        id INTEGER PRIMARY KEY,
        nombre TEXT,
        direccion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE producto(
        id INTEGER PRIMARY KEY,
        id_categoria INTEGER,
        nombre TEXT,
        marca TEXT,
        unidad TEXT,
        stock_minimo INTEGER,
        imagen_ruta TEXT,
        id_tienda INTEGER,
        FOREIGN KEY (id_categoria) REFERENCES categoria(id),
        FOREIGN KEY (id_tienda) REFERENCES tienda(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE lote(
        id INTEGER PRIMARY KEY,
        id_producto INTEGER,
        cantidad INTEGER,
        cantidad_inicial INTEGER NOT NULL DEFAULT 0,
        fecha_caducidad TEXT,
        fecha_ingreso TEXT,
        activo INTEGER,
        FOREIGN KEY (id_producto) REFERENCES producto(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE historial(
        id INTEGER PRIMARY KEY,
        id_producto INTEGER,
        id_lote INTEGER,
        id_tienda INTEGER,
        cantidad INTEGER,
        precio_unitario REAL,
        fecha_compra TEXT,
        FOREIGN KEY (id_producto) REFERENCES producto(id),
        FOREIGN KEY (id_lote) REFERENCES lote(id),
        FOREIGN KEY (id_tienda) REFERENCES tienda(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE alertas(
        id INTEGER PRIMARY KEY,
        id_producto INTEGER,
        id_lote INTEGER,
        fecha_alerta TEXT,
        tipo TEXT,
        notificada INTEGER DEFAULT 0,
        FOREIGN KEY (id_producto) REFERENCES producto(id),
        FOREIGN KEY (id_lote) REFERENCES lote(id)
      )
    ''');

    await _crearTablaMovimientos(db);
    await _crearTablaCarrito(db);
  }

  static Future<void> _crearTablaCarrito(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS carrito(
        id_producto INTEGER PRIMARY KEY,
        cantidad INTEGER NOT NULL DEFAULT 1
          CHECK(cantidad > 0),
        fecha_agregado TEXT NOT NULL,
        FOREIGN KEY (id_producto) REFERENCES producto(id)
      )
    ''');
  }

  static Future<void> _crearTablaMovimientos(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimiento_lote(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_lote INTEGER NOT NULL,
        tipo TEXT NOT NULL
          CHECK(tipo IN ('consumo', 'desecho')),
        cantidad INTEGER NOT NULL CHECK(cantidad > 0),
        motivo TEXT,
        fecha_movimiento TEXT NOT NULL,
        FOREIGN KEY (id_lote) REFERENCES lote(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movimiento_lote_fecha
      ON movimiento_lote(fecha_movimiento)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movimiento_lote_lote
      ON movimiento_lote(id_lote)
    ''');
  }
}
