import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class AlertasDao {
  int? id;
  int? idProducto;
  int? idLote;
  String? fechaAlerta;
  String? tipo;
  int? notificada;

  AlertasDao({
    this.id,
    this.idProducto,
    this.idLote,
    this.fechaAlerta,
    this.tipo,
    this.notificada,
  });

  factory AlertasDao.fromMap(Map<String, dynamic> alerta) {
    return AlertasDao(
      id: alerta['id'],
      idProducto: alerta['id_producto'],
      idLote: alerta['id_lote'],
      fechaAlerta: alerta['fecha_alerta'],
      tipo: alerta['tipo'],
      notificada: alerta['notificada'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_producto': idProducto,
      'id_lote': idLote,
      'fecha_alerta': fechaAlerta,
      'tipo': tipo,
      'notificada': notificada,
    };
  }

  static Future<Database> _getDatabase() async {
    final db = await Conexion().database;
    if (db == null) {
      throw Exception('No se pudo inicializar la base de datos.');
    }
    return db;
  }

  static Future<int> insertar(AlertasDao alerta) async {
    final db = await _getDatabase();
    return await db.insert(
      'alertas',
      alerta.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AlertasDao>> obtenerTodos() async {
    final db = await _getDatabase();
    final maps = await db.query('alertas', orderBy: 'id ASC');
    return maps.map((map) => AlertasDao.fromMap(map)).toList();
  }

  static Future<List<AlertasDao>> obtenerPorProducto(int idProducto) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'alertas',
      where: 'id_producto = ?',
      whereArgs: [idProducto],
      orderBy: 'id ASC',
    );
    return maps.map((map) => AlertasDao.fromMap(map)).toList();
  }

  static Future<AlertasDao?> obtenerPorId(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'alertas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return AlertasDao.fromMap(result.first);
  }

  static Future<int> actualizar(AlertasDao alerta) async {
    if (alerta.id == null) {
      throw Exception('La alerta debe tener un id para actualizarse.');
    }

    final db = await _getDatabase();
    return await db.update(
      'alertas',
      alerta.toMap(),
      where: 'id = ?',
      whereArgs: [alerta.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'alertas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

