
class TiendaDao {
  int? id;
  String? nombre;
  String? direccion;

TiendaDao({this.id,this.nombre,this.direccion});

factory TiendaDao.fromMap(Map <String,dynamic> tienda){
  return TiendaDao(
    id: tienda['dao'],
    nombre: tienda['nombre'],
    direccion: tienda['direccion']
  );
}





}