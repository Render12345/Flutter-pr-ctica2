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

  late Future<List<Map<String, Object?>>> _movimientos;

  String _filtro = 'todos';

  @override
  void initState() {
    super.initState();
    _movimientos = _obtenerMovimientos();
  }

  Future<List<Map<String, Object?>>> _obtenerMovimientos() async {
    final db = await Conexion().database;

    if (db == null) {
      throw Exception('No se pudo abrir la base de datos.');
    }

    return db.rawQuery('''
      SELECT
        'compra' AS tipo,
        h.id AS id,
        p.nombre AS producto,
        p.unidad AS unidad,
        t.nombre AS tienda,
        h.cantidad AS cantidad,
        h.precio_unitario AS precio_unitario,
        h.fecha_compra AS fecha,
        NULL AS motivo
      FROM historial h
      LEFT JOIN producto p ON p.id = h.id_producto
      LEFT JOIN tienda t ON t.id = h.id_tienda

      UNION ALL

      SELECT
        ml.tipo AS tipo,
        ml.id AS id,
        p.nombre AS producto,
        p.unidad AS unidad,
        NULL AS tienda,
        ml.cantidad AS cantidad,
        NULL AS precio_unitario,
        ml.fecha_movimiento AS fecha,
        ml.motivo AS motivo
      FROM movimiento_lote ml
      INNER JOIN lote l ON l.id = ml.id_lote
      LEFT JOIN producto p ON p.id = l.id_producto

      ORDER BY fecha DESC, id DESC
    ''');
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  String _formatoFecha(Object? valor) {
    if (valor == null || valor.toString().isEmpty) {
      return 'Sin fecha';
    }

    final fecha = DateTime.tryParse(valor.toString());

    if (fecha == null) return valor.toString();

    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case 'compra':
        return 'Compra';
      case 'consumo':
        return 'Consumo';
      case 'desecho':
        return 'Desecho';
      default:
        return tipo;
    }
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'compra':
        return Icons.shopping_cart_outlined;
      case 'consumo':
        return Icons.restaurant_outlined;
      case 'desecho':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'compra':
        return Colors.green;
      case 'consumo':
        return Colors.blue;
      case 'desecho':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: 'Historial de movimientos',
      body: SafeArea(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: _movimientos,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error al cargar el historial:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final movimientos = snapshot.data!;

            final compras = movimientos
                .where((m) => m['tipo'] == 'compra')
                .toList();

            final consumos = movimientos
                .where((m) => m['tipo'] == 'consumo')
                .length;

            final desechos = movimientos
                .where((m) => m['tipo'] == 'desecho')
                .length;

            final totalGastado = compras.fold<double>(
              0,
              (suma, compra) {
                final precio =
                    (compra['precio_unitario'] as num?)?.toDouble() ?? 0;
                final cantidad =
                    (compra['cantidad'] as num?)?.toInt() ?? 0;

                return suma + precio * cantidad;
              },
            );

            final texto = _busqueda.text.trim().toLowerCase();

            final filtrados = movimientos.where((movimiento) {
              final tipo = movimiento['tipo']?.toString() ?? '';

              final coincideTipo =
                  _filtro == 'todos' || tipo == _filtro;

              final contenido = [
                movimiento['producto'] ?? '',
                movimiento['tienda'] ?? '',
                movimiento['motivo'] ?? '',
                _nombreTipo(tipo),
              ].join(' ').toLowerCase();

              return coincideTipo && contenido.contains(texto);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _busqueda,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar producto, tienda o motivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${compras.length} compras · '
                        '$consumos consumos · '
                        '$desechos desechos',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total gastado en compras: '
                        '\$${totalGastado.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filtroBoton('Todos', 'todos'),
                        const SizedBox(width: 8),
                        _filtroBoton('Compras', 'compra'),
                        const SizedBox(width: 8),
                        _filtroBoton('Consumos', 'consumo'),
                        const SizedBox(width: 8),
                        _filtroBoton('Desechos', 'desecho'),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: filtrados.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay movimientos que coincidan.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            final movimiento = filtrados[index];

                            final tipo =
                                movimiento['tipo']?.toString() ?? '';

                            final cantidad =
                                (movimiento['cantidad'] as num?)?.toInt() ??
                                    0;

                            final precio =
                                (movimiento['precio_unitario'] as num?)
                                    ?.toDouble();

                            final unidad =
                                movimiento['unidad']?.toString() ?? '';

                            final color = _colorTipo(tipo);

                            String detalle =
                                'Cantidad: $cantidad $unidad';

                            if (tipo == 'compra') {
                              final tienda =
                                  movimiento['tienda']?.toString() ??
                                      'Tienda no especificada';

                              detalle += '\nTienda: $tienda';

                              if (precio != null) {
                                detalle +=
                                    '\nPrecio unitario: '
                                    '\$${precio.toStringAsFixed(2)}'
                                    '\nSubtotal: '
                                    '\$${(precio * cantidad).toStringAsFixed(2)}';
                              } else {
                                detalle += '\nPrecio no registrado';
                              }
                            } else if (tipo == 'desecho') {
                              final motivo =
                                  movimiento['motivo']?.toString() ?? '';

                              detalle +=
                                  '\nMotivo: ${motivo.isEmpty ? 'No especificado' : motivo}';
                            }

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(
                                    _iconoTipo(tipo),
                                    color: color,
                                  ),
                                ),
                                title: Text(
                                  movimiento['producto']?.toString() ??
                                      'Producto no disponible',
                                ),
                                subtitle: Text(
                                  '${_nombreTipo(tipo)} · '
                                  '${_formatoFecha(movimiento['fecha'])}'
                                  '\n$detalle',
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
      ),
    );
  }

  Widget _filtroBoton(String texto, String valor) {
    return ChoiceChip(
      label: Text(texto),
      selected: _filtro == valor,
      onSelected: (_) {
        setState(() => _filtro = valor);
      },
    );
  }
}
