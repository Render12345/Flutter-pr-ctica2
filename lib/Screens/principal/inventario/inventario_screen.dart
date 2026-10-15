import 'package:flutter/material.dart';
import 'package:practica_2/config/conexion.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final TextEditingController _busqueda = TextEditingController();
  int? _categoriaSeleccionada;
  String _disponibilidad = 'Todos';

  Future<List<Map<String, Object?>>> _obtenerInventario() async {
    final db = await Conexion().database;
    return db!.rawQuery('''
      SELECT p.id, p.nombre, p.marca, p.unidad, p.stock_minimo, p.imagen_ruta,
        p.id_categoria, c.nombre AS categoria,
        COALESCE(SUM(CASE WHEN l.activo = 1 THEN l.cantidad ELSE 0 END), 0) AS stock
      FROM producto p
      LEFT JOIN categoria c ON c.id = p.id_categoria
      LEFT JOIN lote l ON l.id_producto = p.id
      GROUP BY p.id
      ORDER BY p.nombre COLLATE NOCASE
    ''');
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _mostrarDetalle(Map<String, Object?> producto) async {
    final db = await Conexion().database;
    final lotes = await db!.rawQuery(
      'SELECT * FROM lote WHERE id_producto = ? ORDER BY fecha_caducidad',
      [producto['id']],
    );
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(producto['nombre'] as String? ?? 'Producto'),
        content: SizedBox(
          width: 420,
          child: lotes.isEmpty
              ? const Text('Este producto aún no tiene lotes registrados.')
              : ListView(
                  shrinkWrap: true,
                  children: lotes
                      .map(
                        (lote) => ListTile(
                          leading: const Icon(Icons.layers_outlined),
                          title: Text(
                            '${lote['cantidad'] ?? 0} ${producto['unidad'] ?? ''}',
                          ),
                          subtitle: Text(
                            'Caducidad: ${lote['fecha_caducidad'] ?? 'Sin fecha'}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _obtenerInventario(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Text('Error al cargar inventario: ${snapshot.error}'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        final categorias = <int, String>{};
        for (final row in rows) {
          final id = row['id_categoria'] as int?;
          final nombre = row['categoria'] as String?;
          if (id != null && nombre != null) categorias[id] = nombre;
        }
        final filtrados = rows.where((row) {
          final texto = _busqueda.text.trim().toLowerCase();
          final coincideTexto =
              texto.isEmpty ||
              '${row['nombre']} ${row['marca'] ?? ''}'.toLowerCase().contains(
                texto,
              );
          final coincideCategoria =
              _categoriaSeleccionada == null ||
              row['id_categoria'] == _categoriaSeleccionada;
          final stock = (row['stock'] as num?)?.toInt() ?? 0;
          final minimo = (row['stock_minimo'] as num?)?.toInt() ?? 0;
          final coincideEstado =
              _disponibilidad == 'Todos' ||
              (_disponibilidad == 'Disponible' && stock > minimo) ||
              (_disponibilidad == 'Bajo' && stock > 0 && stock <= minimo) ||
              (_disponibilidad == 'Agotado' && stock == 0);
          return coincideTexto && coincideCategoria && coincideEstado;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar productos',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  DropdownButton<int?>(
                    value: _categoriaSeleccionada,
                    hint: const Text('Categoría'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todas las categorías'),
                      ),
                      ...categorias.entries.map(
                        (entry) => DropdownMenuItem<int?>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _categoriaSeleccionada = value),
                  ),
                  DropdownButton<String>(
                    value: _disponibilidad,
                    items: ['Todos', 'Disponible', 'Bajo', 'Agotado']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _disponibilidad = value ?? 'Todos'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay productos que coincidan con los filtros.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final producto = filtrados[index];
                        final stock = (producto['stock'] as num?)?.toInt() ?? 0;
                        final minimo =
                            (producto['stock_minimo'] as num?)?.toInt() ?? 0;
                        final estado = stock == 0
                            ? 'Agotado'
                            : stock <= minimo
                            ? 'Stock bajo'
                            : 'Disponible';
                        return Card(
                          child: ListTile(
                            onTap: () => _mostrarDetalle(producto),
                            leading: const CircleAvatar(
                              child: Icon(Icons.inventory_2_outlined),
                            ),
                            title: Text(
                              producto['nombre'] as String? ?? 'Producto',
                            ),
                            subtitle: Text(
                              '${producto['categoria'] ?? 'Sin categoría'} · ${producto['marca'] ?? ''}\n$stock ${producto['unidad'] ?? ''} · $estado',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
