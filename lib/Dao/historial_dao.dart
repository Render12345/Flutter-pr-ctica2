class HistorialDao {
  int? id;
  int? id_producto;
  int? id_lote;
  int? id_tienda;
  int? cantidad;
  int? precio_unitario;
  String? fecha_compra;

  HistorialDao({
    this.id,
    this.id_producto,
    this.id_lote,
    this.id_tienda,
    this.cantidad,
    this.precio_unitario,
    this.fecha_compra,
  });

  factory HistorialDao.fromMap(Map<String, dynamic> historial) {
    return HistorialDao(
      id: historial['id'],
      id_producto: historial['id_producto'],
      id_lote: historial['id_lote'],
      id_tienda:historial['id_tienda'] ,
      cantidad: historial['cantidad'],
      precio_unitario: historial['precio_unitario'],
      fecha_compra: historial['fecha_compra'],
    );
  }
}
