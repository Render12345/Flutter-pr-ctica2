import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:practica_2/Screens/principal/calendario/calendario_screen.dart';
import 'package:practica_2/Screens/principal/inicio/inicio_screen.dart';
import 'package:practica_2/Screens/principal/inventario/inventario_screen.dart';
import 'package:practica_2/components/base_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int indiceSeleccionado = 0;
  final List<Widget> ListWidgets = [
    InicioScreen(),
    CalendarioScreen(),
    InventarioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseScreen.m_getBase(
      context: context,
      title: 'Gestión de inventario doméstico',
      body: ListWidgets[indiceSeleccionado],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: indiceSeleccionado,
        onTap: (indice) {
          setState(() {
            indiceSeleccionado = indice;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
        ],
      ),
    );
  }
}
