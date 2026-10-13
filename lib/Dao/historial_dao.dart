import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class HistorialDao {
  int? id;
  int? idProducto;
  int? idLote;
  int? idTienda;
  int? cantidad;
  double? precioUnitario;
  String? fechaCompra;

  HistorialDao({
    this.id,
    this.idProducto,
    this.idLote,
    this.idTienda,
    this.cantidad,
    this.precioUnitario,
    this.fechaCompra,
  });

  factory HistorialDao.fromMap(Map<String, dynamic> historial) {
    return HistorialDao(
      id: historial['id'],
      idProducto: historial['id_producto'],
      idLote: historial['id_lote'],
      idTienda: historial['id_tienda'],
      cantidad: historial['cantidad'],
      precioUnitario: historial['precio_unitario'] is int
          ? (historial['precio_unitario'] as int).toDouble()
          : historial['precio_unitario'],
      fechaCompra: historial['fecha_compra'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_producto': idProducto,
      'id_lote': idLote,
      'id_tienda': idTienda,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'fecha_compra': fechaCompra,
    };
  }

  static Future<Database> _getDatabase() async {
    final db = await Conexion().database;
    if (db == null) {
      throw Exception('No se pudo inicializar la base de datos.');
    }
    return db;
  }

  static Future<int> insertar(HistorialDao historial) async {
    final db = await _getDatabase();
    return await db.insert(
      'historial',
      historial.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<HistorialDao>> obtenerTodos() async {
    final db = await _getDatabase();
    final maps = await db.query('historial', orderBy: 'id ASC');
    return maps.map((map) => HistorialDao.fromMap(map)).toList();
  }

  static Future<List<HistorialDao>> obtenerPorProducto(int idProducto) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'historial',
      where: 'id_producto = ?',
      whereArgs: [idProducto],
      orderBy: 'id ASC',
    );
    return maps.map((map) => HistorialDao.fromMap(map)).toList();
  }

  static Future<HistorialDao?> obtenerPorId(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'historial',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return HistorialDao.fromMap(result.first);
  }

  static Future<int> actualizar(HistorialDao historial) async {
    if (historial.id == null) {
      throw Exception('El historial debe tener un id para actualizarse.');
    }

    final db = await _getDatabase();
    return await db.update(
      'historial',
      historial.toMap(),
      where: 'id = ?',
      whereArgs: [historial.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'historial',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

