import 'package:flutter/widgets.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Text("Inventario"),);
  }
}