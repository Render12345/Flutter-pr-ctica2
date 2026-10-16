import 'package:flutter/material.dart';
import 'package:practica_2/config/conexion.dart';
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
    _lotes = _obtenerLotes();
  }

  Future<List<Map<String, Object?>>> _obtenerLotes() async {
    final db = await Conexion().database;
    return db!.rawQuery('''
      SELECT l.id, l.cantidad, l.fecha_caducidad, p.nombre, p.unidad
      FROM lote l JOIN producto p ON p.id = l.id_producto
      WHERE l.activo = 1 AND l.cantidad > 0 AND l.fecha_caducidad IS NOT NULL
      ORDER BY l.fecha_caducidad
    ''');
  }

  DateTime? _fecha(Map<String, Object?> lote) =>
      DateTime.tryParse(lote['fecha_caducidad'] as String? ?? '');

  List<Map<String, Object?>> _eventos(
    DateTime dia,
    List<Map<String, Object?>> lotes,
  ) => lotes.where((lote) {
    final fecha = _fecha(lote);
    return fecha != null && isSameDay(fecha, dia);
  }).toList();

  void _recargar() => setState(() => _lotes = _obtenerLotes());

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
        final eventosSeleccionados = _eventos(_seleccionado ?? _enfoque, lotes);
        return RefreshIndicator(
          onRefresh: () async => _recargar(),
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
                  onDaySelected: (selected, focused) => setState(() {
                    _seleccionado = selected;
                    _enfoque = focused;
                  }),
                  onPageChanged: (focused) => _enfoque = focused,
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
                'Productos para ${_seleccionado?.day}/${_seleccionado?.month}/${_seleccionado?.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (eventosSeleccionados.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No hay productos que caduquen este día.'),
                )
              else
                ...eventosSeleccionados.map(
                  (lote) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: Text(lote['nombre'] as String? ?? 'Producto'),
                      subtitle: Text(
                        'Cantidad: ${lote['cantidad']} ${lote['unidad'] ?? ''} · Caduca: ${lote['fecha_caducidad']}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
