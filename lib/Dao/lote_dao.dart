import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class LoteDao {
  int? id;
  int? idProducto;
  int? cantidad;
  int? cantidadInicial;
  String? fechaCaducidad;
  String? fechaIngreso;
  int? activo;

  LoteDao({
    this.id,
    this.idProducto,
    this.cantidad,
    this.cantidadInicial,
    this.fechaCaducidad,
    this.fechaIngreso,
    this.activo,
  });

  factory LoteDao.fromMap(Map<String, dynamic> lote) {
    return LoteDao(
      id: lote['id'],
      idProducto: lote['id_producto'],
      cantidad: lote['cantidad'],
      cantidadInicial: lote['cantidad_inicial'],
      fechaCaducidad: lote['fecha_caducidad'],
      fechaIngreso: lote['fecha_ingreso'],
      activo: lote['activo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_producto': idProducto,
      'cantidad': cantidad,
      'cantidad_inicial': cantidadInicial ?? cantidad,
      'fecha_caducidad': fechaCaducidad,
      'fecha_ingreso': fechaIngreso,
      'activo': activo,
    };
  }

  static Future<Database> _getDatabase() async {
    final db = await Conexion().database;
    if (db == null) {
      throw Exception('No se pudo inicializar la base de datos.');
    }
    return db;
  }

  static Future<int> insertar(LoteDao lote) async {
    final db = await _getDatabase();
    return await db.insert(
      'lote',
      lote.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<LoteDao>> obtenerTodos() async {
    final db = await _getDatabase();
    final maps = await db.query('lote', orderBy: 'id ASC');
    return maps.map((map) => LoteDao.fromMap(map)).toList();
  }

  static Future<List<LoteDao>> obtenerPorProducto(int idProducto) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'lote',
      where: 'id_producto = ?',
      whereArgs: [idProducto],
      orderBy: 'id ASC',
    );
    return maps.map((map) => LoteDao.fromMap(map)).toList();
  }

  static Future<LoteDao?> obtenerPorId(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'lote',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return LoteDao.fromMap(result.first);
  }

  static Future<int> actualizar(LoteDao lote) async {
    if (lote.id == null) {
      throw Exception('El lote debe tener un id para actualizarse.');
    }

    final db = await _getDatabase();
    return await db.update(
      'lote',
      lote.toMap(),
      where: 'id = ?',
      whereArgs: [lote.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _getDatabase();
    return await db.delete('lote', where: 'id = ?', whereArgs: [id]);
  }
}
