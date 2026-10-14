
import 'package:flutter/material.dart';
import 'package:practica_2/components/base_screen.dart';

class LoteScreen extends StatefulWidget {
  const LoteScreen({super.key});

  @override
  State<LoteScreen> createState() => _LoteScreenState();
}

class _LoteScreenState extends State<LoteScreen> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen.m_getBase(
      context: context,
      title: "Lotes",
      body: Text("Aqui van los Lotes")
    );
  }
}