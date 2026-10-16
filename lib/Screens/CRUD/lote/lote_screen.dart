import 'package:flutter/material.dart';
import 'package:practica_2/Dao/historial_dao.dart';
import 'package:practica_2/Dao/lote_dao.dart';
import 'package:practica_2/Dao/producto_dao.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/components/base_screen.dart';

class LoteScreen extends StatefulWidget {
  const LoteScreen({super.key});

  @override
  State<LoteScreen> createState() => _LoteScreenState();
}

class _LoteScreenState extends State<LoteScreen> {
  late Future<List<Map<String, Object?>>> _lotes;

  @override
  void initState() {
    super.initState();
    _lotes = _obtenerLotes();
  }

  Future<List<Map<String, Object?>>> _obtenerLotes() async {
    final db = await Conexion().database;
    return db!.rawQuery('''
      SELECT l.*, p.nombre AS producto, p.unidad
      FROM lote l JOIN producto p ON p.id = l.id_producto
      ORDER BY l.fecha_caducidad, p.nombre
    ''');
  }

  void _recargar() {
    if (mounted) {
      setState(() => _lotes = _obtenerLotes());
    }
  }

  Future<void> _editar([Map<String, Object?>? existente]) async {
    final productos = await ProductoDao.obtenerTodos();
    if (!mounted) return;
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registra un producto antes de crear lotes.'),
        ),
      );
      return;
    }
    final cantidadInicial = TextEditingController(
      text: '${existente?['cantidad_inicial'] ?? ''}',
    );
    final cantidadActual = TextEditingController(
      text: '${existente?['cantidad'] ?? ''}',
    );
    final precio = TextEditingController();
    int? productoSeleccionado =
        (existente?['id_producto'] as num?)?.toInt() ?? productos.first.id;
    DateTime? fechaCaducidad = DateTime.tryParse(
      existente?['fecha_caducidad'] as String? ?? '',
    );
    bool activo = (existente?['activo'] as int? ?? 1) == 1;
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existente == null ? 'Registrar compra / lote' : 'Editar lote',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: productoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Producto'),
                      items: productos
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.nombre ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: existente == null
                          ? (value) => setDialogState(
                              () => productoSeleccionado = value,
                            )
                          : null,
                    ),
                    TextFormField(
                      controller: cantidadInicial,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad inicial',
                      ),
                      validator: (value) =>
                          int.tryParse(value ?? '') == null ||
                              int.parse(value!) <= 0
                          ? 'Debe ser mayor a 0'
                          : null,
                    ),
                    TextFormField(
                      controller: cantidadActual,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Existencias actuales',
                      ),
                      validator: (value) {
                        final inicial = int.tryParse(cantidadInicial.text);
                        final actual = int.tryParse(value ?? '');
                        return actual == null ||
                                actual < 0 ||
                                (inicial != null && actual > inicial)
                            ? 'Usa un valor entre 0 y la cantidad inicial'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: precio,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario (opcional)',
                      ),
                      validator: (value) =>
                          value != null &&
                              value.isNotEmpty &&
                              double.tryParse(value.replaceAll(',', '.')) ==
                                  null
                          ? 'Ingresa un precio válido'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaCaducidad ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => fechaCaducidad = picked);
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        fechaCaducidad == null
                            ? 'Elegir caducidad'
                            : 'Caduca: ${_formatoFecha(fechaCaducidad!)}',
                      ),
                    ),
                    if (existente != null)
                      SwitchListTile(
                        value: activo,
                        title: const Text('Lote activo'),
                        onChanged: (value) =>
                            setDialogState(() => activo = value),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate() && fechaCaducidad != null) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (guardar == true) {
      final fecha =
          '${fechaCaducidad!.year.toString().padLeft(4, '0')}-${fechaCaducidad!.month.toString().padLeft(2, '0')}-${fechaCaducidad!.day.toString().padLeft(2, '0')}';
      final cantidad = int.parse(cantidadActual.text);
      try {
        if (existente == null) {
          final idLote = await LoteDao.insertar(
            LoteDao(
              idProducto: productoSeleccionado,
              cantidad: cantidad,
              cantidadInicial: int.parse(cantidadInicial.text),
              fechaCaducidad: fecha,
              fechaIngreso: DateTime.now().toIso8601String().substring(0, 10),
              activo: 1,
            ),
          );
          final producto = productos.firstWhere(
            (item) => item.id == productoSeleccionado,
          );
          await HistorialDao.insertar(
            HistorialDao(
              idProducto: productoSeleccionado,
              idLote: idLote,
              idTienda: producto.idTienda,
              cantidad: int.parse(cantidadInicial.text),
              precioUnitario: double.tryParse(precio.text.replaceAll(',', '.')),
              fechaCompra: DateTime.now().toIso8601String().substring(0, 10),
            ),
          );
        } else {
          await LoteDao.actualizar(
            LoteDao(
              id: (existente['id'] as num).toInt(),
              idProducto: productoSeleccionado,
              cantidad: cantidad,
              cantidadInicial: int.parse(cantidadInicial.text),
              fechaCaducidad: fecha,
              fechaIngreso: existente['fecha_ingreso'] as String?,
              activo: activo ? 1 : 0,
            ),
          );
        }
        _recargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      }
    }
    cantidadInicial.dispose();
    cantidadActual.dispose();
    precio.dispose();
  }

  Future<void> _consumir(Map<String, Object?> lote) async {
    final actual = (lote['cantidad'] as num?)?.toInt() ?? 0;
    if (actual == 0) return;
    final cantidad = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar existencias'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: cantidad,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cantidad consumida (disponible: $actual)',
            ),
            validator: (value) {
              final n = int.tryParse(value ?? '');
              return n == null || n <= 0 || n > actual
                  ? 'Ingresa una cantidad entre 1 y $actual'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (guardar == true) {
      try {
        final n = int.parse(cantidad.text);
        await LoteDao.actualizar(
          LoteDao(
            id: (lote['id'] as num).toInt(),
            idProducto: (lote['id_producto'] as num).toInt(),
            cantidad: actual - n,
            cantidadInicial:
                (lote['cantidad_inicial'] as num?)?.toInt() ?? actual,
            fechaCaducidad: lote['fecha_caducidad'] as String?,
            fechaIngreso: lote['fecha_ingreso'] as String?,
            activo: actual == n ? 0 : (lote['activo'] as int? ?? 1),
          ),
        );
        _recargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar existencias: $e')),
          );
        }
      }
    }
    cantidad.dispose();
  }

  String _formatoFecha(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: "Lotes",
      body: SafeArea(
        child: FutureBuilder<List<Map<String, Object?>>>(
        future: _lotes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lotes = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: lotes.isEmpty
                    ? const Center(child: Text('Aún no hay lotes registrados.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: lotes.length,
                        itemBuilder: (context, index) {
                          final lote = lotes[index];
                          final actual =
                              (lote['cantidad'] as num?)?.toInt() ?? 0;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                actual == 0
                                    ? Icons.remove_shopping_cart
                                    : Icons.layers_outlined,
                              ),
                              title: Text(
                                lote['producto'] as String? ?? 'Producto',
                              ),
                              subtitle: Text(
                                'Actual: $actual / Inicial: ${lote['cantidad_inicial'] ?? actual} ${lote['unidad'] ?? ''}\nCaducidad: ${lote['fecha_caducidad'] ?? 'Sin fecha'}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'consume') _consumir(lote);
                                  if (value == 'edit') _editar(lote);
                                },
                                itemBuilder: (context) => [
                                  if (actual > 0)
                                    const PopupMenuItem(
                                      value: 'consume',
                                      child: Text('Consumir / actualizar'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar lote'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _editar,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Registrar compra / lote'),
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}
