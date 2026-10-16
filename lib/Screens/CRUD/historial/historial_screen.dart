import 'package:flutter/material.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/components/base_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final TextEditingController _busqueda = TextEditingController();
  late Future<List<Map<String, Object?>>> _compras;

  @override
  void initState() {
    super.initState();
    _compras = _obtenerCompras();
  }

  Future<List<Map<String, Object?>>> _obtenerCompras() async {
    final db = await Conexion().database;
    return db!.rawQuery('''
      SELECT h.id, h.cantidad, h.precio_unitario, h.fecha_compra,
        p.nombre AS producto, p.unidad, t.nombre AS tienda
      FROM historial h
      LEFT JOIN producto p ON p.id = h.id_producto
      LEFT JOIN tienda t ON t.id = h.id_tienda
      ORDER BY h.fecha_compra DESC, h.id DESC
    ''');
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: "Historial de compras",
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _compras,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final compras = snapshot.data!;
          final texto = _busqueda.text.trim().toLowerCase();
          final filtradas = compras
              .where(
                (compra) =>
                    texto.isEmpty ||
                    '${compra['producto'] ?? ''} ${compra['tienda'] ?? ''}'
                        .toLowerCase()
                        .contains(texto),
              )
              .toList();
          final total = compras.fold<double>(0, (suma, compra) {
            final precio = (compra['precio_unitario'] as num?)?.toDouble() ?? 0;
            final cantidad = (compra['cantidad'] as num?)?.toInt() ?? 0;
            return suma + precio * cantidad;
          });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _busqueda,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Buscar producto o tienda',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${compras.length} compras registradas'),
                    ),
                    Text(
                      'Total: ${total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtradas.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay compras que coincidan. Registra una compra desde Lotes.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtradas.length,
                        itemBuilder: (context, index) {
                          final compra = filtradas[index];
                          final cantidad =
                              (compra['cantidad'] as num?)?.toInt() ?? 0;
                          final precio = (compra['precio_unitario'] as num?)
                              ?.toDouble();
                          final subtotal = precio == null
                              ? null
                              : precio * cantidad;
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(
                                compra['producto'] as String? ??
                                    'Producto eliminado',
                              ),
                              subtitle: Text(
                                '${compra['tienda'] ?? 'Tienda no especificada'} · ${compra['fecha_compra'] ?? 'Sin fecha'}\nCantidad: $cantidad ${compra['unidad'] ?? ''}${precio == null ? '' : ' · Unitario: ${precio.toStringAsFixed(2)} · Total: ${subtotal!.toStringAsFixed(2)}'}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
