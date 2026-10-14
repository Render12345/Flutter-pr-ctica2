import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:practica_2/components/base_screen.dart';
import 'package:practica_2/components/show_dialogs.dart';

class CategoriaScreen extends StatefulWidget {
  const CategoriaScreen({super.key});

  @override
  State<CategoriaScreen> createState() => _CategoriaScreenState();
}

class _CategoriaScreenState extends State<CategoriaScreen> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen.m_getBase(
      context: context,
      title: "Categorías",
      body: ElevatedButton(
        onPressed: () {
          ShowDialogs.pedirConfirmacion(
            context: context,
            title: 'Eliminar categoría',
            message: '¿Deseas eliminar esta categoría?',
            onAccept: () async {
              //final value = await categoriasDB!.DELETE(idCategoria);
              final value = 1;
              if (!context.mounted) return;

              final msj = value == 1? 'Categoría eliminada': 'No se pudo eliminar la categoría';
              ShowDialogs.mostrarResultado(context,msj);

              setState(() {});
            },
          );
        },
        child: Text("Borrar"),
      ),
    );
  }
}
