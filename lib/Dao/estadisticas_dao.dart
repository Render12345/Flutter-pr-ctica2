import 'package:practica_2/config/conexion.dart';

class EstadisticasDao {
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await Conexion().database;

    if (db == null) {
      throw Exception('No se pudo abrir la base de datos.');
    }

    final productos = await db.rawQuery('''
      SELECT
        p.id AS id_producto,
        p.nombre AS nombre,
        p.unidad AS unidad,
        p.imagen_ruta AS imagen_ruta,

        COALESCE((
          SELECT SUM(h.cantidad)
          FROM historial h
          WHERE h.id_producto = p.id
        ), 0) AS cantidad_comprada,

        COALESCE((
          SELECT SUM(ml.cantidad)
          FROM movimiento_lote ml
          INNER JOIN lote l ON l.id = ml.id_lote
          WHERE l.id_producto = p.id
            AND ml.tipo = 'consumo'
        ), 0) AS cantidad_consumida,

        COALESCE((
          SELECT SUM(ml.cantidad)
          FROM movimiento_lote ml
          INNER JOIN lote l ON l.id = ml.id_lote
          WHERE l.id_producto = p.id
            AND ml.tipo = 'desecho'
        ), 0) AS cantidad_desechada,

        COALESCE((
          SELECT SUM(l.cantidad)
          FROM lote l
          WHERE l.id_producto = p.id
            AND l.activo = 1
            AND l.cantidad > 0
        ), 0) AS stock_actual,

        COALESCE((
          SELECT AVG(
            (
              COALESCE((
                SELECT SUM(ml.cantidad)
                FROM movimiento_lote ml
                WHERE ml.id_lote = l.id
                  AND ml.tipo = 'desecho'
              ), 0) * 100.0
            ) /
            NULLIF(
              COALESCE(
                NULLIF(l.cantidad_inicial, 0),
                (
                  SELECT SUM(h.cantidad)
                  FROM historial h
                  WHERE h.id_lote = l.id
                ),
                0
              ),
              0
            )
          )
          FROM lote l
          WHERE l.id_producto = p.id
            AND COALESCE(
              NULLIF(l.cantidad_inicial, 0),
              (
                SELECT SUM(h.cantidad)
                FROM historial h
                WHERE h.id_lote = l.id
              ),
              0
            ) > 0
        ), 0) AS promedio_desperdicio,

        COALESCE((
          SELECT AVG((
            SELECT SUM(ml.cantidad)
            FROM movimiento_lote ml
            WHERE ml.id_lote = l.id
              AND ml.tipo = 'consumo'
          ))
          FROM lote l
          WHERE l.id_producto = p.id
            AND l.cantidad = 0

            AND EXISTS (
              SELECT 1
              FROM movimiento_lote ml
              WHERE ml.id_lote = l.id
                AND ml.tipo = 'consumo'
            )

            AND NOT EXISTS (
              SELECT 1
              FROM movimiento_lote ml
              WHERE ml.id_lote = l.id
                AND ml.tipo = 'desecho'
            )
        ), 0) AS promedio_consumo_lote

      FROM producto p

      ORDER BY promedio_desperdicio DESC,
               cantidad_desechada DESC,
               p.nombre COLLATE NOCASE ASC
    ''');

    double sumar(String campo) {
      return productos.fold<double>(
        0,
        (total, producto) =>
            total + _numero(producto[campo]),
      );
    }

    final comprada = sumar('cantidad_comprada');
    final consumida = sumar('cantidad_consumida');
    final desechada = sumar('cantidad_desechada');

    final porcentajeGlobal = comprada > 0
        ? (desechada / comprada) * 100
        : 0.0;

    return {
      'productos': productos,
      'resumen': {
        'comprada': comprada,
        'consumida': consumida,
        'desechada': desechada,
        'porcentajeGlobal': porcentajeGlobal,
      },
    };
  }

  static double _numero(dynamic valor) {
    if (valor == null) return 0;

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor.toString()) ?? 0;
  }
}
