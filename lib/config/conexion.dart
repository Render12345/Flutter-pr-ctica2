import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Conexion {
  static final nameDB = "Despensa";
  static final version = 2;
  static Database? _database;

  Future<Database?> get database async {
    if (_database != null) return _database;
    return _database = await _initDataBase();
  }

  Future<Database> _initDataBase() async {
    Directory folder = await getApplicationDocumentsDirectory();
    String pathDb = join(folder.path, nameDB);

    return openDatabase(
      pathDb,
      version: version,
      onCreate: createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE lote ADD COLUMN cantidad_inicial INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('UPDATE lote SET cantidad_inicial = cantidad');
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
  }
}
