import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class ProductoDao {
  int? id;
  int? idCategoria;
  String? nombre;
  String? marca;
  String? unidad;
  int? stockMinimo;
  String? imagenRuta;
  int? idTienda;

  ProductoDao({
    this.id,
    this.idCategoria,
    this.nombre,
    this.marca,
    this.unidad,
    this.stockMinimo,
    this.imagenRuta,
    this.idTienda,
  });

  factory ProductoDao.fromMap(Map<String, dynamic> product) {
    return ProductoDao(
      id: product['id'],
      idCategoria: product['id_categoria'],
      nombre: product['nombre'],
      marca: product['marca'],
      unidad: product['unidad'],
      stockMinimo: product['stock_minimo'],
      imagenRuta: product['imagen_ruta'],
      idTienda: product['id_tienda'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id_categoria': idCategoria,
      'nombre': nombre,
      'marca': marca,
      'unidad': unidad,
      'stock_minimo': stockMinimo,
      'imagen_ruta': imagenRuta,
      'id_tienda': idTienda,
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

  static Future<int> insertar(ProductoDao producto) async {
    final db = await _getDatabase();
    return await db.insert(
      'producto',
      producto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ProductoDao>> obtenerTodos() async {
    final db = await _getDatabase();
    final maps = await db.query('producto', orderBy: 'id ASC');
    return maps.map((map) => ProductoDao.fromMap(map)).toList();
  }

  static Future<List<ProductoDao>> obtenerPorCategoria(int idCategoria) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'producto',
      where: 'id_categoria = ?',
      whereArgs: [idCategoria],
      orderBy: 'id ASC',
    );
    return maps.map((map) => ProductoDao.fromMap(map)).toList();
  }

  static Future<ProductoDao?> obtenerPorId(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'producto',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return ProductoDao.fromMap(result.first);
  }

  static Future<int> actualizar(ProductoDao producto) async {
    if (producto.id == null) {
      throw Exception('El producto debe tener un id para actualizarse.');
    }

    final db = await _getDatabase();
    return await db.update(
      'producto',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'producto',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
