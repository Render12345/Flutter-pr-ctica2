import 'package:flutter/material.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/Dao/movimiento_lote_dao.dart';

import 'dart:io';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final TextEditingController _busqueda = TextEditingController();

  int? _categoriaSeleccionada;
  String _disponibilidad = 'Todos';

  late Future<List<Map<String, Object?>>> _inventario;

  @override
  void initState() {
    super.initState();
    _inventario = _obtenerInventario();
  }

  Future<List<Map<String, Object?>>> _obtenerInventario() async {
    final db = await Conexion().database;

    return db!.rawQuery('''
      SELECT
        p.id,
        p.nombre,
        p.marca,
        p.unidad,
        p.stock_minimo,
        p.imagen_ruta,
        p.id_categoria,
        c.nombre AS categoria,
        COALESCE(
          SUM(CASE
            WHEN l.activo = 1 THEN l.cantidad
            ELSE 0
          END),
          0
        ) AS stock
      FROM producto p
      LEFT JOIN categoria c ON c.id = p.id_categoria
      LEFT JOIN lote l ON l.id_producto = p.id
      GROUP BY p.id
      ORDER BY
  CASE
    WHEN COALESCE(SUM(
      CASE WHEN l.activo = 1 THEN l.cantidad ELSE 0 END
    ), 0) = 0 THEN 1

    WHEN COALESCE(SUM(
      CASE WHEN l.activo = 1 THEN l.cantidad ELSE 0 END
    ), 0) <= p.stock_minimo THEN 2

    ELSE 3
  END,
  p.nombre COLLATE NOCASE
    ''');
  }

  Widget _imagenProducto(String? ruta) {
    if (ruta != null && ruta.trim().isNotEmpty) {
      final archivo = File(ruta);

      if (archivo.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            archivo,
            width: 55,
            height: 55,
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
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Colors.blueGrey,
        size: 28,
      ),
    );
  }

  Future<void> _recargar() async {
    if (!mounted) return;

    setState(() {
      _inventario = _obtenerInventario();
    });

    await _inventario;
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _mostrarDetalle(Map<String, Object?> producto) async {
    final db = await Conexion().database;

    final lotes = await db!.rawQuery(
      '''
      SELECT *
      FROM lote
      WHERE id_producto = ?
        AND activo = 1
        AND cantidad > 0
      ORDER BY
        CASE
          WHEN fecha_caducidad IS NULL THEN 1
          ELSE 0
        END,
        fecha_caducidad
      ''',
      [producto['id']],
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(producto['nombre'] as String? ?? 'Producto'),
        content: SizedBox(
          width: 420,
          child: lotes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Este producto no tiene lotes activos '
                    'con existencias.',
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Existencias: '
                        '${producto['stock'] ?? 0} '
                        '${producto['unidad'] ?? ''}',
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...lotes.map((lote) {
                      final cantidad = (lote['cantidad'] as num?)?.toInt() ?? 0;

                      final fecha = lote['fecha_caducidad'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 12,
                            right: 4,
                          ),
                          leading: const Icon(Icons.layers_outlined),
                          title: Text(
                            '$cantidad '
                            '${producto['unidad'] ?? ''}',
                          ),
                          subtitle: Text('Caducidad: ${_formatoFecha(fecha)}'),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Acciones del lote',
                            onSelected: (value) {
                              Navigator.of(dialogContext).pop();

                              if (value == 'consumo') {
                                _registrarSalida(
                                  lote,
                                  producto,
                                  tipo: 'consumo',
                                );
                              } else if (value == 'desecho') {
                                _registrarSalida(
                                  lote,
                                  producto,
                                  tipo: 'desecho',
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'consumo',
                                child: Row(
                                  children: [
                                    Icon(Icons.restaurant),
                                    SizedBox(width: 10),
                                    Text('Consumir'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'desecho',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline),
                                    SizedBox(width: 10),
                                    Text('Desechar'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarSalida(
    Map<String, Object?> lote,
    Map<String, Object?> producto, {
    required String tipo,
  }) async {
    final disponible = (lote['cantidad'] as num?)?.toInt() ?? 0;

    final idLote = (lote['id'] as num).toInt();

    final nombre = producto['nombre'] as String? ?? 'Producto';

    if (disponible <= 0) {
      _mensaje('Este lote ya no tiene existencias.');
      await _recargar();
      return;
    }

    final resultado = await showDialog<_SalidaResult>(
      context: context,
      builder: (_) =>
          _SalidaDialog(tipo: tipo, disponible: disponible, producto: nombre),
    );

    if (resultado == null || !mounted) return;

    try {
      await MovimientoLoteDao.registrarSalida(
        idLote: idLote,
        tipo: tipo,
        cantidad: resultado.cantidad,
        motivo: resultado.motivo,
      );

      await _recargar();

      if (!mounted) return;

      _mensaje(
        tipo == 'consumo'
            ? 'Consumo registrado correctamente.'
            : 'Desecho registrado correctamente.',
      );
    } catch (e) {
      _mensaje('No se pudo registrar el movimiento: $e');
      await _recargar();
    }
  }

  String _formatoFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) {
      return 'Sin fecha';
    }

    final parsed = DateTime.tryParse(fecha);

    if (parsed == null) return fecha;

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _inventario,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar inventario: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data!;

        final categorias = <int, String>{};

        for (final row in rows) {
          final id = (row['id_categoria'] as num?)?.toInt();
          final nombre = row['categoria'] as String?;

          if (id != null && nombre != null) {
            categorias[id] = nombre;
          }
        }

        final texto = _busqueda.text.trim().toLowerCase();

        final filtrados = rows.where((row) {
          final coincideTexto =
              texto.isEmpty ||
              '${row['nombre']} ${row['marca'] ?? ''}'.toLowerCase().contains(
                texto,
              );

          final idCategoria = (row['id_categoria'] as num?)?.toInt();

          final coincideCategoria =
              _categoriaSeleccionada == null ||
              idCategoria == _categoriaSeleccionada;

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
                    onChanged: (value) {
                      setState(() {
                        _categoriaSeleccionada = value;
                      });
                    },
                  ),
                  DropdownButton<String>(
                    value: _disponibilidad,
                    items: ['Todos', 'Disponible', 'Bajo', 'Agotado'].map((
                      value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _disponibilidad = value ?? 'Todos';
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay productos que coincidan '
                        'con los filtros.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _recargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtrados.length,
                        itemBuilder: (context, index) {
                          final producto = filtrados[index];

                          final stock =
                              (producto['stock'] as num?)?.toInt() ?? 0;

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
                              leading: _imagenProducto(
                                producto['imagen_ruta']?.toString(),
                              ),
                              title: Text(
                                producto['nombre'] as String? ?? 'Producto',
                              ),
                              subtitle: Text(
                                '${producto['categoria'] ?? 'Sin categoría'}'
                                ' · ${producto['marca'] ?? ''}\n'
                                '$stock ${producto['unidad'] ?? ''}'
                                ' · $estado',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SalidaResult {
  final int cantidad;
  final String? motivo;

  const _SalidaResult({required this.cantidad, this.motivo});
}

class _SalidaDialog extends StatefulWidget {
  final String tipo;
  final int disponible;
  final String producto;

  const _SalidaDialog({
    required this.tipo,
    required this.disponible,
    required this.producto,
  });

  @override
  State<_SalidaDialog> createState() => _SalidaDialogState();
}

class _SalidaDialogState extends State<_SalidaDialog> {
  late final TextEditingController _cantidad;
  late final TextEditingController _motivo;

  final _formKey = GlobalKey<FormState>();

  bool get _esDesecho => widget.tipo == 'desecho';

  @override
  void initState() {
    super.initState();
    _cantidad = TextEditingController(text: '1');
    _motivo = TextEditingController();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      _SalidaResult(
        cantidad: int.parse(_cantidad.text),
        motivo: _esDesecho ? _motivo.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_esDesecho ? 'Desechar producto' : 'Consumir producto'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.producto,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text('Existencias disponibles: ${widget.disponible}'),
              TextFormField(
                controller: _cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                validator: (value) {
                  final numero = int.tryParse(value ?? '');

                  if (numero == null ||
                      numero <= 0 ||
                      numero > widget.disponible) {
                    return 'Ingresa una cantidad entre '
                        '1 y ${widget.disponible}';
                  }

                  return null;
                },
              ),
              if (_esDesecho)
                TextFormField(
                  controller: _motivo,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del desecho',
                    hintText: 'Ej. Producto caducado o deteriorado',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Indica el motivo del desecho';
                    }

                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(_esDesecho ? 'Confirmar desecho' : 'Confirmar consumo'),
        ),
      ],
    );
  }
}
