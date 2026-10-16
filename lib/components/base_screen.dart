import 'package:flutter/material.dart';

class BaseScreen {
  static Widget buildBase({
    required BuildContext context,
    required String title,
    required Widget body,
    Widget? bottomNavigationBar,
    Widget? floatingActionButton, //Ahora es Opcional (Widget?) y sin 'required'
  }) {
    void navegarA(String ruta) {
      // Cerrar el menú desplegable.
      Navigator.pop(context);

      // Reemplazar la pantalla CRUD actual.
      Navigator.pushReplacementNamed(context, ruta);
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('resources/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        /*************************Barra Superior*********************************/
        appBar: AppBar(
          title: Text(title),
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromARGB(255, 6, 63, 109),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
          ),
        ),
        /****************************Menu Desplegable********************************/
        endDrawer: Drawer(
          backgroundColor: const Color.fromARGB(255, 6, 63, 109),
          child: ListTileTheme(
            data: const ListTileThemeData(
              textColor: Colors.white,
              iconColor: Colors.white,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const DrawerHeader(
                    child: Center(
                      child: Text(
                        'Menú de opciones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.category),
                          title: const Text('Categorías'),
                          onTap: () => navegarA('/categoria'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.store),
                          title: const Text('Tiendas'),
                          onTap: () => navegarA('/tienda'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: const Text('Productos'),
                          onTap: () => navegarA('/producto'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: const Text('Historial de compras'),
                          onTap: () => navegarA('/historial'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.layers),
                          title: const Text('Lotes'),
                          onTap: () => navegarA('/lote'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white38),
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Cerrar menú'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        /************Contenido principal*****************************/
        body: body,
        /************Botón Flotante (opcional)***********************/
        floatingActionButton: floatingActionButton, 
        /************Menu Inferior (opcional)************************/
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}