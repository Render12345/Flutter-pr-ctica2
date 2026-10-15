import 'dart:io';

import 'package:flutter/material.dart';
import 'package:practica_2/config/conexion.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final Map<int, int> _carrito = {};

  Future<List<Map<String, Object?>>> _obtenerResumen() async {
    final db = await Conexion().database;
    final rows = await db!.rawQuery('''
      SELECT p.id, p.nombre, p.unidad, p.stock_minimo, p.imagen_ruta,
        COALESCE(SUM(CASE WHEN l.activo = 1 THEN l.cantidad ELSE 0 END), 0) AS stock,
        MIN(CASE WHEN l.activo = 1 AND l.cantidad > 0
          AND date(l.fecha_caducidad) >= date('now') THEN l.fecha_caducidad END) AS caducidad
      FROM producto p
      LEFT JOIN lote l ON l.id_producto = p.id
      GROUP BY p.id
      ORDER BY p.nombre COLLATE NOCASE
    ''');
    return rows;
  }

  bool _proximoACaducar(Map<String, Object?> producto) {
    final value = producto['caducidad'] as String?;
    if (value == null) return false;
    final fecha = DateTime.tryParse(value);
    if (fecha == null) return false;
    final hoy = DateTime.now();
    final dias = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    return dias >= 0 && dias <= 7;
  }

  void _agregarAlCarrito(int id) {
    setState(() => _carrito[id] = (_carrito[id] ?? 0) + 1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto agregado al carrito')),
    );
  }

  Widget _imagen(String? ruta) {
    if (ruta != null && ruta.isNotEmpty && File(ruta).existsSync()) {
      return Image.file(File(ruta), width: 54, height: 54, fit: BoxFit.cover);
    }
    return const CircleAvatar(child: Icon(Icons.inventory_2_outlined));
  }

  Widget _productoTile(
    Map<String, Object?> producto, {
    required bool caducidad,
  }) {
    final stock = (producto['stock'] as num?)?.toInt() ?? 0;
    final id = (producto['id'] as num).toInt();
    final fecha = producto['caducidad'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: _imagen(producto['imagen_ruta'] as String?),
        title: Text(producto['nombre'] as String? ?? 'Producto'),
        subtitle: Text(
          caducidad
              ? 'Caduca: ${fecha ?? 'Sin fecha'} · $stock ${producto['unidad'] ?? ''}'
              : 'Existencias: $stock ${producto['unidad'] ?? ''} · ${stock == 0 ? 'Agotado' : 'Stock bajo'}',
        ),
        trailing: IconButton(
          tooltip: 'Agregar al carrito',
          onPressed: () => _agregarAlCarrito(id),
          icon: const Icon(Icons.add_shopping_cart),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _obtenerResumen(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('No se pudo cargar el resumen: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final productos = snapshot.data!;
        final caducan = productos.where(_proximoACaducar).toList();
        final bajos = productos.where((producto) {
          final stock = (producto['stock'] as num?)?.toInt() ?? 0;
          final minimo = (producto['stock_minimo'] as num?)?.toInt() ?? 0;
          return stock <= minimo;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _indicador(
                      'Productos',
                      '${productos.length}',
                      Icons.inventory_2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _indicador(
                      'Por caducar',
                      '${caducan.length}',
                      Icons.event_busy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _indicador(
                      'Stock bajo',
                      '${bajos.length}',
                      Icons.warning_amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _encabezado('Próximos a caducar', Icons.calendar_month),
              if (caducan.isEmpty)
                const _EstadoVacio(
                  texto:
                      'No hay productos que caduquen en los próximos 7 días.',
                )
              else
                ...caducan.map(
                  (producto) => _productoTile(producto, caducidad: true),
                ),
              const SizedBox(height: 12),
              _encabezado(
                'Agotados o con existencias bajas',
                Icons.error_outline,
              ),
              if (bajos.isEmpty)
                const _EstadoVacio(
                  texto: 'Todos los productos están por encima del mínimo.',
                )
              else
                ...bajos.map(
                  (producto) => _productoTile(producto, caducidad: false),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _carrito.isEmpty
                    ? null
                    : () => _mostrarCarrito(productos),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(
                  'Carrito (${_carrito.values.fold<int>(0, (total, cantidad) => total + cantidad)})',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _indicador(String titulo, String valor, IconData icono) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icono, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(valor, style: Theme.of(context).textTheme.titleLarge),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(String texto, IconData icono) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icono),
        const SizedBox(width: 8),
        Text(texto, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  void _mostrarCarrito(List<Map<String, Object?>> productos) {
    final porId = {
      for (final producto in productos)
        (producto['id'] as num).toInt(): producto,
    };
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Carrito', style: Theme.of(context).textTheme.titleLarge),
            ..._carrito.entries.map(
              (entry) => ListTile(
                title: Text(
                  porId[entry.key]?['nombre'] as String? ?? 'Producto',
                ),
                subtitle: Text('Cantidad: ${entry.value}'),
                trailing: IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      if (entry.value <= 1) {
                        _carrito.remove(entry.key);
                      } else {
                        _carrito[entry.key] = entry.value - 1;
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
  );
}
