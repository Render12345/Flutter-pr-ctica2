import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class CategoriaDao {
  int? id;
  String? nombre;
  String? descripcion;

  CategoriaDao({this.id, this.nombre, this.descripcion});

  factory CategoriaDao.fromMap(Map<String, dynamic> category) {
    return CategoriaDao(
      id: category['id'],
      nombre: category['nombre'],
      descripcion: category['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'descripcion': descripcion,
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

  static Future<int> insertar(CategoriaDao categoria) async {
    final db = await _getDatabase();
    return await db.insert(
      'categoria',
      categoria.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CategoriaDao>> obtenerTodos() async {
    final db = await _getDatabase();
    final maps = await db.query('categoria', orderBy: 'id ASC');
    return maps.map((map) => CategoriaDao.fromMap(map)).toList();
  }

  static Future<CategoriaDao?> obtenerPorId(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'categoria',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return CategoriaDao.fromMap(result.first);
  }

  static Future<int> actualizar(CategoriaDao categoria) async {
    if (categoria.id == null) {
      throw Exception('La categoría debe tener un id para actualizarse.');
    }

    final db = await _getDatabase();
    return await db.update(
      'categoria',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'categoria',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}