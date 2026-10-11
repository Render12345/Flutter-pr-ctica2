
class ProductoDao {
  int? id;
  int? id_categoria;
  String? nombre;
  String? marca;
  String? unidad;
  int? stock_minimo;
  String? imagen_ruta;
  int? id_tienda;

  ProductoDao({
    this.id,
    this.id_categoria,
    this.nombre,
    this.marca,
    this.unidad,
    this.stock_minimo,
    this.imagen_ruta,
    this.id_tienda
    });

  factory ProductoDao.fromMap(Map <String,dynamic> product){
    return ProductoDao(
    id:product['id'],
    id_categoria:product['id_categoria'],
    nombre:product['nombre'],
    marca:product['marca'],
    unidad:product['unidad'],
    stock_minimo:product['stock_minimo'],
    imagen_ruta:product['imagen_ruta'],
    id_tienda:product['id_tienda']
    );
  } 
}