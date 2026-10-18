import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class CompraDao {
  Future<int> registrarCompra({
    required int idTienda,
    required String fechaCompra,
    required List<Map<String, Object?>> productos,
  }) async {
    if (productos.isEmpty) {
      throw ArgumentError('El carrito está vacío.');
    }

    final db = await Conexion().database;

    if (db == null) {
      throw StateError('No se pudo abrir la base de datos.');
    }

    return db.transaction<int>((txn) async {
      int registros = 0;

      for (final producto in productos) {
        final int idProducto = producto['idProducto'] as int;
        final int cantidad = producto['cantidad'] as int;
        final double? precio =
            (producto['precioUnitario'] as num?)?.toDouble();
        final String fechaIngreso =
            producto['fechaIngreso'] as String;
        final String fechaCaducidad =
            producto['fechaCaducidad'] as String;

        if (cantidad <= 0) {
          throw ArgumentError(
            'La cantidad debe ser mayor que cero.',
          );
        }

        if (fechaCaducidad.compareTo(fechaIngreso) < 0) {
          throw ArgumentError(
            'La caducidad no puede ser anterior al ingreso.',
          );
        }

        // Crear un lote nuevo para esta compra.
        final int idLote = await txn.insert('lote', {
          'id_producto': idProducto,
          'cantidad': cantidad,
          'cantidad_inicial': cantidad,
          'fecha_caducidad': fechaCaducidad,
          'fecha_ingreso': fechaIngreso,
          'activo': 1,
        });

        // Registrar la compra asociada al lote creado.
        await txn.insert('historial', {
          'id_producto': idProducto,
          'id_lote': idLote,
          'id_tienda': idTienda,
          'cantidad': cantidad,
          'precio_unitario': precio,
          'fecha_compra': fechaCompra,
        });

        registros++;
      }

      return registros;
    });
  }
}
