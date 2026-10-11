import 'package:flutter/material.dart';

class AlertasDao {
  int? id;
  int? id_producto;
  int? id_lote;
  String? fecha_alerta;
  Text? tipo;
  int? notificada;

  AlertasDao({
    this.id,
    this.id_producto,
    this.id_lote,
    this.fecha_alerta,
    this.tipo,
    this.notificada,
  });

  factory AlertasDao.fromMap(Map<String,dynamic> alerta){
    return AlertasDao(
    id:alerta['id'],
    id_producto:alerta['id_producto'],
    id_lote:alerta['id_lote'],
    fecha_alerta:alerta['fecha_alerta'],
    tipo:alerta['tipo'],
    notificada:alerta['notificada'],    
    );
  }

}
