
import 'package:flutter/material.dart';
import 'package:practica_2/components/base_screen.dart';

class ProductoScreen extends StatefulWidget {
  const ProductoScreen({super.key});

  @override
  State<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends State<ProductoScreen> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen.m_getBase(
      context: context,
      title: "Productos",
      body: Text("Aqui van los productos")
    );
  }
}