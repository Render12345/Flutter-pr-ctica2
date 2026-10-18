import 'dart:io';

import 'package:flutter/material.dart';
import 'package:practica_2/Dao/estadisticas_dao.dart';
import 'package:practica_2/components/base_screen.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final EstadisticasDao _dao = EstadisticasDao();

  late Future<Map<String, dynamic>> _estadisticas;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  void _cargarEstadisticas() {
    _estadisticas = _dao.obtenerEstadisticas();
  }

  void _actualizarEstadisticas() {
    setState(() {
      _cargarEstadisticas();
    });
  }

  double _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  String _formato(double valor) => valor.toStringAsFixed(2);

  String _cantidad(dynamic valor, String unidad) {
    final cantidad = _formato(_numero(valor));

    return unidad.trim().isEmpty ? cantidad : '$cantidad $unidad';
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: 'Estadísticas',
      floatingActionButton: FloatingActionButton(
        onPressed: _actualizarEstadisticas,
        tooltip: 'Actualizar estadísticas',
        child: const Icon(Icons.refresh),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _estadisticas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar las estadísticas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _actualizarEstadisticas,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No hay estadísticas disponibles.'),
            );
          }

          final datos = snapshot.data!;
          final resumen = datos['resumen'] as Map<String, dynamic>;
          final productos = (datos['productos'] as List).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen general',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    _tarjetaResumen(
                      'Comprado',
                      _formato(_numero(resumen['comprada'])),
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                    _tarjetaResumen(
                      'Consumido',
                      _formato(_numero(resumen['consumida'])),
                      Icons.restaurant,
                      Colors.green,
                    ),
                    _tarjetaResumen(
                      'Desechado',
                      _formato(_numero(resumen['desechada'])),
                      Icons.delete_outline,
                      Colors.orange,
                    ),
                    _tarjetaResumen(
                      'Desperdicio global',
                      '${_formato(_numero(resumen['porcentajeGlobal']))}%',
                      Icons.pie_chart_outline,
                      Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Estadísticas por producto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),

                const Text(
                  'El consumo promedio por lote considera '
                  'únicamente lotes terminados por consumo '
                  'y sin movimientos de desecho.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),

                if (productos.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No hay productos registrados.'),
                    ),
                  )
                else
                  ...productos.map((elemento) {
                    final producto = Map<String, dynamic>.from(elemento);

                    final nombre =
                        producto['nombre']?.toString() ?? 'Producto sin nombre';
                    final unidad = producto['unidad']?.toString() ?? '';

                    final promedioConsumo = _numero(
                      producto['promedio_consumo_lote'],
                    );
                    final promedioDesperdicio = _numero(
                      producto['promedio_desperdicio'],
                    );

                    return _tarjetaProducto(
                      producto: producto,
                      nombre: nombre,
                      unidad: unidad,
                      promedioConsumo: promedioConsumo,
                      promedioDesperdicio: promedioDesperdicio,
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tarjetaProducto({
    required Map<String, dynamic> producto,
    required String nombre,
    required String unidad,
    required double promedioConsumo,
    required double promedioDesperdicio,
  }) {
    // Ajusta esta clave si tu tabla usa otro nombre
    // para guardar la ruta de la imagen.
    final rutaImagen = producto['imagen_ruta']?.toString();

    final porcentaje = promedioDesperdicio.clamp(0.0, 100.0).toDouble();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _imagenProducto(rutaImagen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            _datoProducto(
              'Consumo promedio por lote',
              _cantidad(promedioConsumo, unidad),
              Icons.shopping_basket_outlined,
              color: Colors.green,
            ),

            const SizedBox(height: 10),

            _datoProducto(
              'Cantidad comprada',
              _cantidad(producto['cantidad_comprada'], unidad),
              Icons.shopping_cart_outlined,
            ),

            const SizedBox(height: 10),

            _datoProducto(
              'Cantidad consumida',
              _cantidad(producto['cantidad_consumida'], unidad),
              Icons.restaurant_outlined,
              color: Colors.green,
            ),

            const SizedBox(height: 10),

            _datoProducto(
              'Cantidad desechada',
              _cantidad(producto['cantidad_desechada'], unidad),
              Icons.delete_outline,
              color: Colors.orange,
            ),

            const SizedBox(height: 10),

            _datoProducto(
              'Stock actual',
              _cantidad(producto['stock_actual'], unidad),
              Icons.inventory_outlined,
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Desperdicio promedio por lote',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_formato(promedioDesperdicio)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: porcentaje >= 50
                        ? Colors.red
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Barra de porcentaje de desperdicio.
            LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                porcentaje >= 50 ? Colors.red : Colors.orange,
              ),
            ),

            if (promedioConsumo > 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Referencia para la próxima compra: '
                  '${_cantidad(promedioConsumo, unidad)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Aún no hay lotes completamente consumidos '
                'para calcular una referencia.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imagenProducto(String? ruta) {
    if (ruta != null && ruta.trim().isNotEmpty) {
      final archivo = File(ruta);

      if (archivo.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            archivo,
            width: 68,
            height: 68,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _imagenPredeterminada();
            },
          ),
        );
      }
    }

    return _imagenPredeterminada();
  }

  Widget _imagenPredeterminada() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 34,
        color: Colors.blueGrey,
      ),
    );
  }

  Widget _tarjetaResumen(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 25),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valor,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datoProducto(
    String titulo,
    String valor,
    IconData icono, {
    Color color = Colors.black87,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 19, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
