
import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class CarritoDao {
  Future<Database> _obtenerDB() async {
    final db = await Conexion().database;

    if (db == null) {
      throw StateError('No se pudo abrir la base de datos.');
    }

    return db;
  }

  /// Recupera los productos guardados: id del producto -> cantidad.
  Future<Map<int, int>> obtenerCarrito() async {
    final db = await _obtenerDB();
    final filas = await db.query('carrito');

    return {
      for (final fila in filas)
        (fila['id_producto'] as num).toInt():
            (fila['cantidad'] as num).toInt(),
    };
  }

  /// Agrega una unidad. Si ya existe, aumenta su cantidad.
  Future<void> agregar(int idProducto) async {
    final db = await _obtenerDB();

    await db.transaction((txn) async {
      final existentes = await txn.query(
        'carrito',
        columns: ['cantidad'],
        where: 'id_producto = ?',
        whereArgs: [idProducto],
        limit: 1,
      );

      if (existentes.isNotEmpty) {
        final cantidad =
            (existentes.first['cantidad'] as num).toInt();

        await txn.update(
          'carrito',
          {
            'cantidad': cantidad + 1,
          },
          where: 'id_producto = ?',
          whereArgs: [idProducto],
        );
      } else {
        await txn.insert('carrito', {
          'id_producto': idProducto,
          'cantidad': 1,
          'fecha_agregado': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Establece una cantidad específica para un producto.
  /// Si la cantidad es cero o negativa, elimina el producto.
  Future<void> establecerCantidad(
    int idProducto,
    int cantidad,
  ) async {
    if (cantidad <= 0) {
      await eliminar(idProducto);
      return;
    }

    final db = await _obtenerDB();

    final existentes = await db.query(
      'carrito',
      columns: ['id_producto'],
      where: 'id_producto = ?',
      whereArgs: [idProducto],
      limit: 1,
    );

    if (existentes.isNotEmpty) {
      await db.update(
        'carrito',
        {'cantidad': cantidad},
        where: 'id_producto = ?',
        whereArgs: [idProducto],
      );
    } else {
      await db.insert('carrito', {
        'id_producto': idProducto,
        'cantidad': cantidad,
        'fecha_agregado': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> eliminar(int idProducto) async {
    final db = await _obtenerDB();

    await db.delete(
      'carrito',
      where: 'id_producto = ?',
      whereArgs: [idProducto],
    );
  }

  Future<void> vaciar() async {
    final db = await _obtenerDB();
    await db.delete('carrito');
  }
}
