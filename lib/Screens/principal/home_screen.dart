import 'package:flutter/material.dart';
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
  final List<Widget> listWidgets = [
    InicioScreen(),
    CalendarioScreen(),
    InventarioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: 'Gestión de inventario doméstico',
      body: listWidgets[indiceSeleccionado],
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
