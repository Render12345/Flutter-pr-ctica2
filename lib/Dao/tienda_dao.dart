import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class TiendaDao {
  int? id;
  String? nombre;
  String? direccion;

  TiendaDao({this.id, this.nombre, this.direccion});

  factory TiendaDao.fromMap(Map<String, dynamic> tienda) {
    return TiendaDao(
      id: tienda['id'],
      nombre: tienda['nombre'],
      direccion: tienda['direccion'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'direccion': direccion,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  static Future<Database> _getDatabase() async {
    final db = await Conexion().database;
    if (db == null) {
      throw Exception('No se pudo inicializar la base de datos.');
    }
    return db;
  }

  static Future<int> insertar(TiendaDao tienda) async {
    final db = await _getDatabase();
    return await db.insert(
      'tienda',
      tienda.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TiendaDao>> obtenerTodos() async {
    final db = await _getDatabase();
    final maps = await db.query('tienda', orderBy: 'id ASC');
    return maps.map((map) => TiendaDao.fromMap(map)).toList();
  }

  static Future<TiendaDao?> obtenerPorId(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'tienda',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return TiendaDao.fromMap(result.first);
  }

  static Future<int> actualizar(TiendaDao tienda) async {
    if (tienda.id == null) {
      throw Exception('La tienda debe tener un id para actualizarse.');
    }

    final db = await _getDatabase();
    return await db.update(
      'tienda',
      tienda.toMap(),
      where: 'id = ?',
      whereArgs: [tienda.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'tienda',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
