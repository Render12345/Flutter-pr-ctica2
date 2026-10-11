
class LoteDao {
  int? id;
  int? id_producto;
  int? cantidad;
  String? fecha_caducidad;
  String? fecha_ingreso;
  int? activo;

  LoteDao({
    this.id,
    this.id_producto,
    this.cantidad,
    this.fecha_caducidad,
    this.fecha_ingreso,
    this.activo,
  });

  factory LoteDao.fromMap(Map<String, dynamic> lote) {
    return LoteDao(
      id:lote['id'],
      id_producto:lote['id_producto'],
      cantidad:lote['cantidad'],
      fecha_caducidad:lote['fecha_caducidad'],
      fecha_ingreso:lote['fecha_ingreso'],
      activo:lote['activo'],
    );
  }
}
