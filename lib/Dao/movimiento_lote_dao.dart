import 'package:practica_2/config/conexion.dart';
import 'package:sqflite/sqflite.dart';

class MovimientoLoteDao {
  int? id;
  int? idLote;
  String? tipo;
  int? cantidad;
  String? motivo;
  String? fechaMovimiento;

  MovimientoLoteDao({
    this.id,
    this.idLote,
    this.tipo,
    this.cantidad,
    this.motivo,
    this.fechaMovimiento,
  });

  factory MovimientoLoteDao.fromMap(Map<String, dynamic> map) {
    return MovimientoLoteDao(
      id: (map['id'] as num?)?.toInt(),
      idLote: (map['id_lote'] as num?)?.toInt(),
      tipo: map['tipo'] as String?,
      cantidad: (map['cantidad'] as num?)?.toInt(),
      motivo: map['motivo'] as String?,
      fechaMovimiento: map['fecha_movimiento'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'id_lote': idLote,
      'tipo': tipo,
      'cantidad': cantidad,
      'motivo': motivo,
      'fecha_movimiento': fechaMovimiento,
    };
  }

  static Future<Database> _getDatabase() async {
    final db = await Conexion().database;

    if (db == null) {
      throw Exception('No se pudo inicializar la base de datos.');
    }

    return db;
  }

  static Future<int> insertar(MovimientoLoteDao movimiento) async {
    if (movimiento.idLote == null) {
      throw ArgumentError('El movimiento debe tener un lote.');
    }

    if (movimiento.tipo != 'consumo' &&
        movimiento.tipo != 'desecho') {
      throw ArgumentError('El tipo debe ser consumo o desecho.');
    }

    if (movimiento.cantidad == null || movimiento.cantidad! <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a cero.');
    }

    if (movimiento.fechaMovimiento == null) {
      throw ArgumentError('La fecha del movimiento es obligatoria.');
    }

    final db = await _getDatabase();

    return db.insert(
      'movimiento_lote',
      movimiento.toMap(),
    );
  }

  static Future<List<MovimientoLoteDao>> obtenerTodos() async {
    final db = await _getDatabase();

    final maps = await db.query(
      'movimiento_lote',
      orderBy: 'fecha_movimiento DESC, id DESC',
    );

    return maps.map(MovimientoLoteDao.fromMap).toList();
  }

  static Future<List<MovimientoLoteDao>> obtenerPorLote(
    int idLote,
  ) async {
    final db = await _getDatabase();

    final maps = await db.query(
      'movimiento_lote',
      where: 'id_lote = ?',
      whereArgs: [idLote],
      orderBy: 'fecha_movimiento DESC, id DESC',
    );

    return maps.map(MovimientoLoteDao.fromMap).toList();
  }

  /// Registra un consumo o desecho y descuenta las existencias
  /// dentro de una misma transacción.
  static Future<void> registrarSalida({
    required int idLote,
    required String tipo,
    required int cantidad,
    String? motivo,
  }) async {
    if (tipo != 'consumo' && tipo != 'desecho') {
      throw ArgumentError('Tipo de movimiento inválido.');
    }

    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a cero.');
    }

    final db = await _getDatabase();
    final ahora = DateTime.now();
    final fecha =
        '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')} '
        '${ahora.hour.toString().padLeft(2, '0')}:'
        '${ahora.minute.toString().padLeft(2, '0')}:'
        '${ahora.second.toString().padLeft(2, '0')}';

    await db.transaction((txn) async {
      final lotes = await txn.query(
        'lote',
        columns: ['cantidad', 'cantidad_inicial', 'activo'],
        where: 'id = ?',
        whereArgs: [idLote],
        limit: 1,
      );

      if (lotes.isEmpty) {
        throw Exception('El lote ya no existe.');
      }

      final lote = lotes.first;
      final actual = (lote['cantidad'] as num?)?.toInt() ?? 0;

      if (cantidad > actual) {
        throw Exception(
          'No hay suficientes existencias. Disponibles: $actual.',
        );
      }

      final restante = actual - cantidad;

      await txn.update(
        'lote',
        {
          'cantidad': restante,
          'activo': restante == 0 ? 0 : lote['activo'],
        },
        where: 'id = ?',
        whereArgs: [idLote],
      );

      await txn.insert(
        'movimiento_lote',
        {
          'id_lote': idLote,
          'tipo': tipo,
          'cantidad': cantidad,
          'motivo': motivo?.trim().isEmpty ?? true
              ? null
              : motivo!.trim(),
          'fecha_movimiento': fecha,
        },
      );
    });
  }
}
