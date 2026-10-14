
import 'package:flutter/material.dart';
import 'package:practica_2/components/base_screen.dart';

class TiendaScreen extends StatefulWidget {
  const TiendaScreen({super.key});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen.m_getBase(
      context: context,
      title: "Tiendas",
      body: Text("Aqui van las Tiendas")
    );
  }
}