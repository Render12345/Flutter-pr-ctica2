import 'dart:io';

import 'package:flutter/material.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/Dao/movimiento_lote_dao.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _enfoque = DateTime.now();
  DateTime? _seleccionado = DateTime.now();

  late Future<List<Map<String, Object?>>> _lotes;

  @override
  void initState() {
    super.initState();

    debugPrint('CALENDARIO: initState ejecutado');

    _lotes = _obtenerLotes();
  }

  Future<List<Map<String, Object?>>> _obtenerLotes() async {
    final db = await Conexion().database;

    return db!.rawQuery('''
      SELECT
        l.id,
        l.cantidad,
        l.fecha_caducidad,
        p.nombre,
        p.unidad,
        p.imagen_ruta
      FROM lote l
      JOIN producto p ON p.id = l.id_producto
      WHERE l.activo = 1
        AND l.cantidad > 0
        AND l.fecha_caducidad IS NOT NULL
      ORDER BY l.fecha_caducidad
    ''');
  }

  DateTime? _fecha(Map<String, Object?> lote) {
    final valor = lote['fecha_caducidad'] as String?;
    return DateTime.tryParse(valor ?? '');
  }

  List<Map<String, Object?>> _eventos(
    DateTime dia,
    List<Map<String, Object?>> lotes,
  ) {
    return lotes.where((lote) {
      final fecha = _fecha(lote);
      return fecha != null && isSameDay(fecha, dia);
    }).toList();
  }

  Future<void> _recargar() async {
    if (!mounted) return;

    setState(() {
      _lotes = _obtenerLotes();
    });

    await _lotes;
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String _formatoFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 'Sin fecha';

    final parsed = DateTime.tryParse(fecha);
    if (parsed == null) return fecha;

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  Future<void> _registrarSalida(
    Map<String, Object?> lote, {
    required String tipo,
  }) async {
    final disponible = (lote['cantidad'] as num?)?.toInt() ?? 0;
    final idLote = (lote['id'] as num).toInt();
    final producto = lote['nombre'] as String? ?? 'Producto';

    if (disponible <= 0) {
      _mensaje('Este lote ya no tiene existencias.');
      await _recargar();
      return;
    }

    final resultado = await showDialog<_SalidaResult>(
      context: context,
      builder: (_) =>
          _SalidaDialog(tipo: tipo, disponible: disponible, producto: producto),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _lotes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar alertas: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final lotes = snapshot.data!;
        final dia = _seleccionado ?? _enfoque;
        final eventosSeleccionados = _eventos(dia, lotes);

        return RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: TableCalendar<Map<String, Object?>>(
                  locale: 'es_ES',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _enfoque,
                  selectedDayPredicate: (day) => isSameDay(_seleccionado, day),
                  eventLoader: (day) => _eventos(day, lotes),
                  calendarFormat: CalendarFormat.month,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _seleccionado = selected;
                      _enfoque = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    _enfoque = focused;
                  },
                  calendarStyle: const CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Colors.deepOrange,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.blueGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Productos para ${dia.day}/${dia.month}/${dia.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (eventosSeleccionados.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No hay productos que caduquen este día.'),
                )
              else
                ...eventosSeleccionados.map((lote) {
                  final nombre = lote['nombre'] as String? ?? 'Producto';
                  final ruta = lote['imagen_ruta'] as String?;
                  final cantidad = (lote['cantidad'] as num?)?.toInt() ?? 0;
                  final unidad = lote['unidad'] as String? ?? '';

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Imagen del producto
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ruta == null || ruta.isEmpty
                                ? Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.black12,
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 28,
                                    ),
                                  )
                                : Image.file(
                                    File(ruta),
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.black12,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          size: 28,
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(width: 10),

                          // Información del producto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  nombre,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Existencias: $cantidad $unidad',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  'Caduca: ${_formatoFecha(lote['fecha_caducidad'] as String?)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // Menú de acciones
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Acciones del producto',
                            onSelected: (value) {
                              if (value == 'consume') {
                                _registrarSalida(lote, tipo: 'consumo');
                              } else if (value == 'discard') {
                                _registrarSalida(lote, tipo: 'desecho');
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'consume',
                                enabled: cantidad > 0,
                                child: const Row(
                                  children: [
                                    Icon(Icons.restaurant),
                                    SizedBox(width: 10),
                                    Text('Consumir'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'discard',
                                enabled: cantidad > 0,
                                child: const Row(
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
                }),
            ],
          ),
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
                    return 'Ingresa una cantidad entre 1 y ${widget.disponible}';
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
