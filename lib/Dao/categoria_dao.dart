
class CategoriaDao {
  int? id;
  String? nombre;
  String? descripcion;

  CategoriaDao({this.id,this.nombre,this.descripcion});

  //constructor nombrado
  factory CategoriaDao.fromMap(Map <String,dynamic> category){
    return CategoriaDao(
      id:category['id'],
      nombre: category['nombre'],
      descripcion: category['descripcion']
    );
  }

}