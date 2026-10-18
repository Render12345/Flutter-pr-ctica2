import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:practica_2/Screens/CRUD/categoria/categoria_screen.dart';
import 'package:practica_2/Screens/CRUD/historial/historial_screen.dart';
import 'package:practica_2/Screens/CRUD/lote/lote_screen.dart';
import 'package:practica_2/Screens/CRUD/producto/producto_screen.dart';
import 'package:practica_2/Screens/CRUD/tienda/tienda_screen.dart';
import 'package:practica_2/Screens/principal/estadisticas/estadisticas_screen.dart';
import 'package:practica_2/Screens/principal/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',
      routes: {
        '/home': (context) => HomeScreen(),
        '/categoria': (context) => CategoriaScreen(),
        '/tienda': (context) => TiendaScreen(),
        '/producto': (context) => ProductoScreen(),
        '/historial': (context) => HistorialScreen(),
        '/lote': (context) => LoteScreen(),
         '/estadisticas': (context) =>
            const EstadisticasScreen(),
      },
    );
  }
}
