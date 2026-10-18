
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:practica_2/Dao/carrito_dao.dart';
import 'package:practica_2/Dao/movimiento_lote_dao.dart';
import 'package:practica_2/Screens/principal/inicio/compra_screen.dart';
import 'package:practica_2/config/conexion.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final Map<int, int> _carrito = {};
  final CarritoDao _carritoDao = CarritoDao();

  late Future<List<Map<String, Object?>>> _resumen;

  bool _cargandoCarrito = true;
  bool _actualizandoCarrito = false;

  @override
  void initState() {
    super.initState();
    _resumen = _obtenerResumen();
    _cargarCarrito();
  }

  // Recupera el carrito guardado en SQLite.
  Future<void> _cargarCarrito() async {
    try {
      final carritoGuardado = await _carritoDao.obtenerCarrito();

      if (!mounted) return;

      setState(() {
        _carrito
          ..clear()
          ..addAll(carritoGuardado);

        _cargandoCarrito = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargandoCarrito = false;
      });

      _mensaje('No se pudo recuperar la lista de compras: $e');
    }
  }

  // Carga los productos, sus existencias y las fechas de caducidad.
  Future<List<Map<String, Object?>>> _obtenerResumen() async {
    final db = await Conexion().database;

    if (db == null) {
      throw StateError('No se pudo abrir la base de datos.');
    }

    return db.rawQuery('''
      SELECT
        p.id,
        p.nombre,
        p.unidad,
        p.stock_minimo,
        p.imagen_ruta,

        COALESCE(
          SUM(
            CASE
              WHEN l.activo = 1 THEN l.cantidad
              ELSE 0
            END
          ),
          0
        ) AS stock,

        MIN(
          CASE
            WHEN l.activo = 1
              AND l.cantidad > 0
              AND l.fecha_caducidad IS NOT NULL
              AND date(l.fecha_caducidad) >= date('now', 'localtime')
            THEN l.fecha_caducidad
          END
        ) AS caducidad,

        COALESCE(
          SUM(
            CASE
              WHEN l.activo = 1
                AND l.cantidad > 0
                AND l.fecha_caducidad IS NOT NULL
                AND date(l.fecha_caducidad) < date('now', 'localtime')
              THEN l.cantidad
              ELSE 0
            END
          ),
          0
        ) AS caducados,

        MIN(
          CASE
            WHEN l.activo = 1
              AND l.cantidad > 0
              AND l.fecha_caducidad IS NOT NULL
              AND date(l.fecha_caducidad) < date('now', 'localtime')
            THEN l.fecha_caducidad
          END
        ) AS caducidad_caducada

      FROM producto p
      LEFT JOIN lote l ON l.id_producto = p.id
      GROUP BY p.id
      ORDER BY p.nombre COLLATE NOCASE
    ''');
  }

  Future<void> _recargar() async {
    if (!mounted) return;

    setState(() {
      _resumen = _obtenerResumen();
    });

    try {
      await _resumen;
    } catch (_) {
      // El FutureBuilder muestra el error de carga.
    }
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Productos que caducan hoy o dentro de los próximos siete días.
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
    ).difference(
      DateTime(hoy.year, hoy.month, hoy.day),
    ).inDays;

    return dias >= 0 && dias <= 7;
  }

  // Identifica productos que tienen al menos un lote caducado
  // con existencias disponibles.
  bool _estaCaducado(Map<String, Object?> producto) {
    final cantidad = (producto['caducados'] as num?)?.toInt() ?? 0;
    return cantidad > 0;
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

  // Agrega una unidad y la guarda inmediatamente en SQLite.
  Future<void> _agregarAlCarrito(int id) async {
    if (_actualizandoCarrito || _cargandoCarrito) return;

    setState(() {
      _actualizandoCarrito = true;
    });

    try {
      await _carritoDao.agregar(id);

      final carritoGuardado = await _carritoDao.obtenerCarrito();

      if (!mounted) return;

      setState(() {
        _carrito
          ..clear()
          ..addAll(carritoGuardado);
      });

      _mensaje('Producto agregado a la lista de compras.');
    } catch (e) {
      _mensaje('No se pudo guardar el producto: $e');
    } finally {
      if (mounted) {
        setState(() {
          _actualizandoCarrito = false;
        });
      }
    }
  }

  int get _cantidadCarrito {
    return _carrito.values.fold<int>(
      0,
      (total, cantidad) => total + cantidad,
    );
  }

  Widget _imagen(String? ruta) {
    if (ruta != null && ruta.isNotEmpty) {
      final archivo = File(ruta);

      if (archivo.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            archivo,
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const CircleAvatar(
                child: Icon(Icons.inventory_2_outlined),
              );
            },
          ),
        );
      }
    }

    return const CircleAvatar(
      child: Icon(Icons.inventory_2_outlined),
    );
  }

  Widget _productoTile(
    Map<String, Object?> producto, {
    required bool caducidad,
    bool mostrarCaducada = false,
  }) {
    final stock = (producto['stock'] as num?)?.toInt() ?? 0;
    final minimo = (producto['stock_minimo'] as num?)?.toInt() ?? 0;
    final id = (producto['id'] as num).toInt();

    final fecha = mostrarCaducada
        ? producto['caducidad_caducada'] as String?
        : producto['caducidad'] as String?;

    final nombre = producto['nombre'] as String? ?? 'Producto';
    final unidad = producto['unidad'] as String? ?? '';

    final cantidadCaducada =
        (producto['caducados'] as num?)?.toInt() ?? 0;

    final estado = stock == 0
        ? 'Agotado'
        : stock <= minimo
            ? 'Stock bajo'
            : 'Disponible';

    String subtitulo;

    if (mostrarCaducada) {
      subtitulo = 'Caducó: ${_formatoFecha(fecha)}\n'
          'Cantidad caducada: $cantidadCaducada $unidad';
    } else if (caducidad) {
      subtitulo = 'Caduca: ${_formatoFecha(fecha)}\n'
          'Existencias: $stock $unidad';
    } else {
      subtitulo = 'Existencias: $stock $unidad · $estado';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: 12,
          right: 4,
          top: 4,
          bottom: 4,
        ),
        leading: _imagen(producto['imagen_ruta'] as String?),
        title: Text(nombre),
        subtitle: Text(subtitulo),
        isThreeLine: caducidad,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Agregar a la lista de compras',
              onPressed: _cargandoCarrito || _actualizandoCarrito
                  ? null
                  : () => _agregarAlCarrito(id),
              icon: const Icon(Icons.add_shopping_cart),
            ),
            PopupMenuButton<String>(
              tooltip: 'Acciones del producto',
              onSelected: (value) {
                if (value == 'lotes') {
                  _mostrarLotes(producto);
                } else if (value == 'consumo') {
                  _mostrarLotes(
                    producto,
                    accionInicial: 'consumo',
                  );
                } else if (value == 'desecho') {
                  _mostrarLotes(
                    producto,
                    accionInicial: 'desecho',
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'lotes',
                  child: Row(
                    children: [
                      Icon(Icons.layers_outlined),
                      SizedBox(width: 10),
                      Text('Ver lotes'),
                    ],
                  ),
                ),
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
          ],
        ),
      ),
    );
  }

  // Muestra los lotes de un producto, ordenados por caducidad.
  Future<void> _mostrarLotes(
    Map<String, Object?> producto, {
    String? accionInicial,
  }) async {
    final db = await Conexion().database;

    if (db == null) {
      _mensaje('No se pudo abrir la base de datos.');
      return;
    }

    final lotes = await db.rawQuery(
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

    if (lotes.isEmpty) {
      _mensaje(
        'Este producto no tiene lotes activos con existencias.',
      );
      return;
    }

    final seleccion = await showDialog<_SeleccionLote>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(
            accionInicial == null
                ? 'Lotes de ${producto['nombre']}'
                : accionInicial == 'consumo'
                    ? 'Selecciona el lote a consumir'
                    : 'Selecciona el lote a desechar',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...lotes.map((lote) {
                  final cantidad =
                      (lote['cantidad'] as num?)?.toInt() ?? 0;
                  final fecha = lote['fecha_caducidad'] as String?;

                  final estaCaducado = fecha != null &&
                      fecha.isNotEmpty &&
                      DateTime.tryParse(fecha) != null &&
                      DateTime(
                        DateTime.parse(fecha).year,
                        DateTime.parse(fecha).month,
                        DateTime.parse(fecha).day,
                      ).isBefore(
                        DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                      );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        estaCaducado
                            ? Icons.warning_amber
                            : Icons.layers_outlined,
                        color: estaCaducado ? Colors.red : null,
                      ),
                      title: Text('$cantidad ${producto['unidad'] ?? ''}'),
                      subtitle: Text(
                        '${estaCaducado ? 'CADUCADO · ' : ''}'
                        'Caducidad: ${_formatoFecha(fecha)}',
                      ),
                      onTap: accionInicial == null
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop(
                                _SeleccionLote(
                                  lote: lote,
                                  tipo: accionInicial,
                                ),
                              );
                            },
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Acciones del lote',
                        onSelected: (tipo) {
                          Navigator.of(dialogContext).pop(
                            _SeleccionLote(
                              lote: lote,
                              tipo: tipo,
                            ),
                          );
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
                if (accionInicial != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Selecciona un lote para continuar.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );

    if (seleccion == null || !mounted) return;

    await _registrarSalida(
      seleccion.lote,
      producto,
      tipo: seleccion.tipo,
    );
  }

  Future<void> _registrarSalida(
    Map<String, Object?> lote,
    Map<String, Object?> producto, {
    required String tipo,
  }) async {
    final disponible = (lote['cantidad'] as num?)?.toInt() ?? 0;

    if (disponible <= 0) {
      _mensaje('Este lote ya no tiene existencias.');
      await _recargar();
      return;
    }

    final idLote = (lote['id'] as num).toInt();
    final nombre = producto['nombre'] as String? ?? 'Producto';

    final resultado = await showDialog<_SalidaResult>(
      context: context,
      builder: (_) => _SalidaDialog(
        tipo: tipo,
        disponible: disponible,
        producto: nombre,
        unidad: producto['unidad'] as String? ?? '',
      ),
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

  // Abre el carrito y persiste cada cambio de cantidad.
  Future<void> _mostrarCarrito(
    List<Map<String, Object?>> productos,
  ) async {
    final porId = {
      for (final producto in productos)
        (producto['id'] as num).toInt(): producto,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final entradas = _carrito.entries
                .where((entry) => porId.containsKey(entry.key))
                .toList();

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Lista de compras',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (_carrito.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Vaciar lista'),
                                      content: const Text(
                                        '¿Quieres eliminar todos '
                                        'los productos de la lista?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(dialogContext)
                                                .pop(false);
                                          },
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.of(dialogContext)
                                                .pop(true);
                                          },
                                          child: const Text('Vaciar'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmar != true) return;

                                try {
                                  await _carritoDao.vaciar();

                                  if (!mounted) return;

                                  setState(() {
                                    _carrito.clear();
                                  });

                                  setModalState(() {});

                                  _mensaje('Lista de compras vaciada.');
                                } catch (e) {
                                  _mensaje(
                                    'No se pudo vaciar la lista: $e',
                                  );
                                }
                              },
                              child: const Text('Vaciar'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: entradas.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.remove_shopping_cart_outlined,
                                      size: 44,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Tu lista de compras está vacía.',
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Agrega productos desde Inicio.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: entradas.length,
                              itemBuilder: (context, index) {
                                final entry = entradas[index];
                                final producto = porId[entry.key]!;

                                final nombre =
                                    producto['nombre'] as String? ??
                                        'Producto';
                                final unidad =
                                    producto['unidad'] as String? ?? '';

                                return ListTile(
                                  leading: _imagen(
                                    producto['imagen_ruta'] as String?,
                                  ),
                                  title: Text(nombre),
                                  subtitle: Text(
                                    'Cantidad: ${entry.value} $unidad',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Disminuir cantidad',
                                        visualDensity:
                                            VisualDensity.compact,
                                        onPressed: () async {
                                          final nuevaCantidad =
                                              entry.value - 1;

                                          try {
                                            await _carritoDao
                                                .establecerCantidad(
                                              entry.key,
                                              nuevaCantidad,
                                            );

                                            if (!mounted) return;

                                            setState(() {
                                              if (nuevaCantidad <= 0) {
                                                _carrito.remove(entry.key);
                                              } else {
                                                _carrito[entry.key] =
                                                    nuevaCantidad;
                                              }
                                            });

                                            setModalState(() {});
                                          } catch (e) {
                                            _mensaje(
                                              'No se pudo cambiar la cantidad: $e',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text('${entry.value}'),
                                      IconButton(
                                        tooltip: 'Aumentar cantidad',
                                        visualDensity:
                                            VisualDensity.compact,
                                        onPressed: () async {
                                          try {
                                            await _carritoDao
                                                .establecerCantidad(
                                              entry.key,
                                              entry.value + 1,
                                            );

                                            if (!mounted) return;

                                            setState(() {
                                              _carrito[entry.key] =
                                                  entry.value + 1;
                                            });

                                            setModalState(() {});
                                          } catch (e) {
                                            _mensaje(
                                              'No se pudo cambiar la cantidad: $e',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar producto',
                                        onPressed: () async {
                                          try {
                                            await _carritoDao.eliminar(
                                              entry.key,
                                            );

                                            if (!mounted) return;

                                            setState(() {
                                              _carrito.remove(entry.key);
                                            });

                                            setModalState(() {});
                                          } catch (e) {
                                            _mensaje(
                                              'No se pudo eliminar el producto: $e',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total de unidades: $_cantidadCarrito',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: entradas.isEmpty
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    _comprar(productos);
                                  },
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                            ),
                            label: const Text('Comprar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Registra la compra y limpia SQLite solo cuando hay éxito.
  Future<void> _comprar(
    List<Map<String, Object?>> productos,
  ) async {
    if (_carrito.isEmpty) return;

    final porId = {
      for (final producto in productos)
        (producto['id'] as num).toInt(): producto,
    };

    final seleccionados = <Map<String, Object?>>[];

    for (final entry in _carrito.entries) {
      final producto = porId[entry.key];

      if (producto == null) {
        _mensaje(
          'Uno de los productos ya no está disponible. '
          'Actualiza el inventario e inténtalo de nuevo.',
        );
        await _recargar();
        return;
      }

      seleccionados.add({
        'idProducto': entry.key,
        'nombre': producto['nombre'],
        'unidad': producto['unidad'],
        'cantidad': entry.value,
      });
    }

    try {
      final registros = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => CompraScreen(
            productos: seleccionados,
          ),
        ),
      );

      if (registros == null || !mounted) return;

      await _carritoDao.vaciar();

      if (!mounted) return;

      setState(() {
        _carrito.clear();
      });

      await _recargar();

      if (!mounted) return;

      _mensaje(
        'Compra registrada correctamente. '
        'Se crearon $registros lotes.',
      );
    } catch (e) {
      if (!mounted) return;

      _mensaje('No se pudo completar la compra: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _resumen,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudo cargar el resumen: ${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final productos = snapshot.data!;

        final caducan = productos
            .where(_proximoACaducar)
            .toList();

        final caducados = productos
            .where(_estaCaducado)
            .toList();

        final bajos = productos.where((producto) {
          final stock =
              (producto['stock'] as num?)?.toInt() ?? 0;
          final minimo =
              (producto['stock_minimo'] as num?)?.toInt() ?? 0;

          return stock <= minimo;
        }).toList();

        return RefreshIndicator(
          onRefresh: _recargar,
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _indicador(
                      'Por caducar',
                      '${caducan.length}',
                      Icons.event_busy,
                    ),
                  ),
                  const SizedBox(width: 8),
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

              _encabezado(
                'Próximos a caducar',
                Icons.calendar_month,
              ),

              if (caducan.isEmpty)
                const _EstadoVacio(
                  texto: 'No hay productos que caduquen '
                      'en los próximos 7 días.',
                )
              else
                ...caducan.map(
                  (producto) => _productoTile(
                    producto,
                    caducidad: true,
                  ),
                ),

              const SizedBox(height: 12),

              _encabezado(
                'Productos caducados',
                Icons.warning_amber,
              ),

              if (caducados.isEmpty)
                const _EstadoVacio(
                  texto: 'No hay productos caducados '
                      'con existencias.',
                )
              else
                ...caducados.map(
                  (producto) => _productoTile(
                    producto,
                    caducidad: true,
                    mostrarCaducada: true,
                  ),
                ),

              const SizedBox(height: 12),

              _encabezado(
                'Agotados o con existencias bajas',
                Icons.error_outline,
              ),

              if (bajos.isEmpty)
                const _EstadoVacio(
                  texto: 'Todos los productos están por '
                      'encima del mínimo.',
                )
              else
                ...bajos.map(
                  (producto) => _productoTile(
                    producto,
                    caducidad: false,
                  ),
                ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cargandoCarrito || _carrito.isEmpty
                      ? null
                      : () => _mostrarCarrito(productos),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.blueGrey.shade200,
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                  ),
                  label: Text(
                    _cargandoCarrito
                        ? 'Cargando lista de compras...'
                        : 'Lista de compras ($_cantidadCarrito)',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _indicador(
    String titulo,
    String valor,
    IconData icono,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              valor,
              style: Theme.of(context).textTheme.titleLarge,
            ),
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

  Widget _encabezado(
    String texto,
    IconData icono,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icono),
          const SizedBox(width: 8),
          Text(
            texto,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _SeleccionLote {
  final Map<String, Object?> lote;
  final String tipo;

  const _SeleccionLote({
    required this.lote,
    required this.tipo,
  });
}

class _SalidaResult {
  final int cantidad;
  final String? motivo;

  const _SalidaResult({
    required this.cantidad,
    this.motivo,
  });
}

class _SalidaDialog extends StatefulWidget {
  final String tipo;
  final int disponible;
  final String producto;
  final String unidad;

  const _SalidaDialog({
    required this.tipo,
    required this.disponible,
    required this.producto,
    required this.unidad,
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
      title: Text(
        _esDesecho ? 'Desechar producto' : 'Consumir producto',
      ),
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
              Text(
                'Disponibles: ${widget.disponible} ${widget.unidad}',
              ),
              TextFormField(
                controller: _cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                ),
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
                    hintText:
                        'Ej. Producto caducado o deteriorado',
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
          child: Text(
            _esDesecho
                ? 'Confirmar desecho'
                : 'Confirmar consumo',
          ),
        ),
      ],
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.texto,
  });

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
