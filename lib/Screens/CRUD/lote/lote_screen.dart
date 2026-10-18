
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:practica_2/Dao/historial_dao.dart';
import 'package:practica_2/Dao/lote_dao.dart';
import 'package:practica_2/Dao/producto_dao.dart';
import 'package:practica_2/Dao/movimiento_lote_dao.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/components/base_screen.dart';

class LoteScreen extends StatefulWidget {
  const LoteScreen({super.key});

  @override
  State<LoteScreen> createState() => _LoteScreenState();
}

class _LoteScreenState extends State<LoteScreen> {
  late Future<List<Map<String, Object?>>> _lotes;

  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _lotes = _obtenerLotes();
  }

  Future<List<Map<String, Object?>>> _obtenerLotes() async {
    final db = await Conexion().database;

    return db!.rawQuery('''
      SELECT
        l.*,
        p.nombre AS producto,
        p.unidad AS unidad,
        p.imagen_ruta AS imagen_ruta
      FROM lote l
      JOIN producto p ON p.id = l.id_producto
      WHERE l.cantidad > 0
      ORDER BY
        CASE
          WHEN l.fecha_caducidad IS NULL OR l.fecha_caducidad = ''
          THEN 1
          ELSE 0
        END,
        l.fecha_caducidad ASC,
        p.nombre COLLATE NOCASE ASC
    ''');
  }

  void _recargar() {
    if (!mounted) return;

    setState(() {
      _lotes = _obtenerLotes();
    });
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _editar([Map<String, Object?>? existente]) async {
    final productos = await ProductoDao.obtenerTodos();

    if (!mounted) return;

    if (productos.isEmpty) {
      _mensaje('Registra un producto antes de crear lotes.');
      return;
    }

    final resultado = await showDialog<_LoteFormResult>(
      context: context,
      builder: (_) => _LoteDialog(
        productos: productos,
        existente: existente,
      ),
    );

    if (resultado == null || !mounted) return;

    try {
      final fecha = _fechaISO(resultado.fechaCaducidad);
      final fechaHoy = _fechaISO(DateTime.now());

      if (existente == null) {
        final cantidad = resultado.cantidadInicial;

        final idLote = await LoteDao.insertar(
          LoteDao(
            idProducto: resultado.productoId,
            cantidad: cantidad,
            cantidadInicial: cantidad,
            fechaCaducidad: fecha,
            fechaIngreso: fechaHoy,
            activo: 1,
          ),
        );

        final producto = productos.firstWhere(
          (item) => item.id == resultado.productoId,
        );

        await HistorialDao.insertar(
          HistorialDao(
            idProducto: resultado.productoId,
            idLote: idLote,
            idTienda: producto.idTienda,
            cantidad: cantidad,
            precioUnitario: resultado.precio,
            fechaCompra: fechaHoy,
          ),
        );

        _mensaje('Compra y lote registrados correctamente.');
      } else {
        final idLote = (existente['id'] as num).toInt();

        await LoteDao.actualizar(
          LoteDao(
            id: idLote,
            idProducto: (existente['id_producto'] as num).toInt(),
            cantidad: resultado.cantidadActual,
            cantidadInicial:
                (existente['cantidad_inicial'] as num?)?.toInt() ??
                (existente['cantidad'] as num?)?.toInt() ??
                0,
            fechaCaducidad: fecha,
            fechaIngreso: existente['fecha_ingreso'] as String?,
            activo: resultado.activo ? 1 : 0,
          ),
        );

        _mensaje('Lote actualizado correctamente.');
      }

      _recargar();
    } catch (e) {
      _mensaje('Error al guardar el lote: $e');
    }
  }

  Future<void> _registrarSalida(
    Map<String, Object?> lote, {
    required String tipo,
  }) async {
    final actual = (lote['cantidad'] as num?)?.toInt() ?? 0;
    final idLote = (lote['id'] as num).toInt();

    if (actual <= 0) {
      _mensaje('Este lote ya no tiene existencias.');
      return;
    }

    final resultado = await showDialog<_SalidaResult>(
      context: context,
      builder: (_) => _SalidaDialog(
        tipo: tipo,
        disponible: actual,
        producto: lote['producto'] as String? ?? 'Producto',
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

      _recargar();

      _mensaje(
        tipo == 'consumo'
            ? 'Consumo registrado correctamente.'
            : 'Desecho registrado correctamente.',
      );
    } catch (e) {
      _mensaje('No se pudo registrar el movimiento: $e');
      _recargar();
    }
  }

  String _fechaISO(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }

  String _formatoFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 'Sin fecha';

    final parsed = DateTime.tryParse(fecha);
    if (parsed == null) return fecha;

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  bool _estaCaducado(String? fecha) {
    if (fecha == null || fecha.isEmpty) return false;

    final parsed = DateTime.tryParse(fecha);
    if (parsed == null) return false;

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

    return parsed.isBefore(hoySinHora);
  }

  Widget _imagenProducto(Map<String, Object?> lote) {
    final ruta = lote['imagen_ruta'] as String?;

    if (ruta != null && ruta.isNotEmpty && File(ruta).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(ruta),
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.inventory_2_outlined,
            size: 34,
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 30,
      child: Icon(Icons.inventory_2_outlined, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: 'Lotes',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                onChanged: (valor) {
                  setState(() {
                    _busqueda = valor.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Buscar lote por producto',
                  hintText: 'Ej. leche, arroz, huevo...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            setState(() {
                              _busqueda = '';
                            });
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _lotes,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final lotes = snapshot.data!;

                  final lotesFiltrados = lotes.where((lote) {
                    final nombre =
                        (lote['producto'] as String? ?? '').toLowerCase();

                    return nombre.contains(_busqueda);
                  }).toList();

                  if (lotesFiltrados.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _busqueda.isEmpty
                                  ? Icons.inventory_2_outlined
                                  : Icons.search_off,
                              size: 56,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _busqueda.isEmpty
                                  ? 'Aún no hay lotes con existencias.'
                                  : 'No se encontraron lotes para "$_busqueda".',
                              textAlign: TextAlign.center,
                            ),
                            if (_busqueda.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() => _busqueda = '');
                                },
                                child: const Text('Limpiar búsqueda'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${lotesFiltrados.length} '
                            '${lotesFiltrados.length == 1 ? 'lote encontrado' : 'lotes encontrados'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: lotesFiltrados.length,
                          itemBuilder: (context, index) {
                            final lote = lotesFiltrados[index];

                            final actual =
                                (lote['cantidad'] as num?)?.toInt() ?? 0;

                            final inicial =
                                (lote['cantidad_inicial'] as num?)?.toInt() ??
                                actual;

                            final activo =
                                (lote['activo'] as num?)?.toInt() == 1;

                            final fechaCaducidad =
                                lote['fecha_caducidad'] as String?;

                            final caducado = _estaCaducado(fechaCaducidad);

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                leading: _imagenProducto(lote),
                                title: Text(
                                  lote['producto'] as String? ?? 'Producto',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Existencias: $actual ${lote['unidad']}',
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Inicial:$inicial ${lote['unidad']}',
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Caducidad: '
                                        '${_formatoFecha(fechaCaducidad)}',
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _etiqueta(
                                            activo ? 'Activo' : 'Inactivo',
                                            activo
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          if (caducado)
                                            _etiqueta(
                                              'Caducado',
                                              Colors.red,
                                            )
                                          else if (fechaCaducidad != null &&
                                              fechaCaducidad.isNotEmpty)
                                            _etiqueta(
                                              'Por caducidad',
                                              Colors.orange,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Acciones del lote',
                                  onSelected: (value) {
                                    if (value == 'consume') {
                                      _registrarSalida(
                                        lote,
                                        tipo: 'consumo',
                                      );
                                    } else if (value == 'discard') {
                                      _registrarSalida(
                                        lote,
                                        tipo: 'desecho',
                                      );
                                    } else if (value == 'edit') {
                                      _editar(lote);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (actual > 0) ...[
                                      const PopupMenuItem(
                                        value: 'consume',
                                        child: Row(
                                          children: [
                                            Icon(Icons.restaurant),
                                            SizedBox(width: 10),
                                            Text('Consumir'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'discard',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline),
                                            SizedBox(width: 10),
                                            Text('Desechar'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined),
                                          SizedBox(width: 10),
                                          Text('Editar lote'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _editar(),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Registrar compra / lote'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoteFormResult {
  final int productoId;
  final int cantidadInicial;
  final int cantidadActual;
  final double? precio;
  final DateTime fechaCaducidad;
  final bool activo;

  const _LoteFormResult({
    required this.productoId,
    required this.cantidadInicial,
    required this.cantidadActual,
    required this.precio,
    required this.fechaCaducidad,
    required this.activo,
  });
}

class _LoteDialog extends StatefulWidget {
  final List<ProductoDao> productos;
  final Map<String, Object?>? existente;

  const _LoteDialog({
    required this.productos,
    this.existente,
  });

  @override
  State<_LoteDialog> createState() => _LoteDialogState();
}

class _LoteDialogState extends State<_LoteDialog> {
  late final TextEditingController _cantidadInicial;
  late final TextEditingController _cantidadActual;
  late final TextEditingController _precio;

  final _formKey = GlobalKey<FormState>();

  int? _productoSeleccionado;
  DateTime? _fechaCaducidad;
  bool _activo = true;

  bool get _esEdicion => widget.existente != null;

  @override
  void initState() {
    super.initState();

    final existente = widget.existente;

    final cantidadActual =
        (existente?['cantidad'] as num?)?.toInt() ?? 0;

    final cantidadInicial =
        (existente?['cantidad_inicial'] as num?)?.toInt() ??
        cantidadActual;

    _cantidadInicial = TextEditingController(
      text: _esEdicion ? '$cantidadInicial' : '',
    );

    _cantidadActual = TextEditingController(
      text: _esEdicion ? '$cantidadActual' : '',
    );

    _precio = TextEditingController();

    _productoSeleccionado =
        (existente?['id_producto'] as num?)?.toInt() ??
        widget.productos.first.id;

    _fechaCaducidad = DateTime.tryParse(
      existente?['fecha_caducidad'] as String? ?? '',
    );

    _activo = (existente?['activo'] as num?)?.toInt() != 0;
  }

  @override
  void dispose() {
    _cantidadInicial.dispose();
    _cantidadActual.dispose();
    _precio.dispose();
    super.dispose();
  }

  String _formatoFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fechaInicial = _fechaCaducidad ?? hoy;

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (seleccionada != null && mounted) {
      setState(() => _fechaCaducidad = seleccionada);
    }
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_fechaCaducidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la fecha de caducidad.'),
        ),
      );
      return;
    }

    final inicial = int.parse(_cantidadInicial.text);

    final actual = _esEdicion
        ? int.parse(_cantidadActual.text)
        : inicial;

    final precioTexto = _precio.text.trim();

    final precio = precioTexto.isEmpty
        ? null
        : double.parse(precioTexto.replaceAll(',', '.'));

    Navigator.of(context).pop(
      _LoteFormResult(
        productoId: _productoSeleccionado!,
        cantidadInicial: inicial,
        cantidadActual: actual,
        precio: precio,
        fechaCaducidad: _fechaCaducidad!,
        activo: _activo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productoExistente = widget.productos.where(
      (producto) => producto.id == _productoSeleccionado,
    );

    return AlertDialog(
      scrollable: true,
      title: Text(
        _esEdicion ? 'Editar lote' : 'Registrar compra / lote',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_esEdicion)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Producto',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    productoExistente.isEmpty
                        ? 'Producto no disponible'
                        : productoExistente.first.nombre ?? 'Producto',
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _productoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Producto',
                  ),
                  items: widget.productos.map((producto) {
                    return DropdownMenuItem<int>(
                      value: producto.id,
                      child: Text(producto.nombre ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _productoSeleccionado = value);
                  },
                  validator: (value) =>
                      value == null ? 'Selecciona un producto' : null,
                ),
              TextFormField(
                controller: _cantidadInicial,
                keyboardType: TextInputType.number,
                readOnly: _esEdicion,
                decoration: InputDecoration(
                  labelText: _esEdicion
                      ? 'Cantidad inicial (solo lectura)'
                      : 'Cantidad comprada',
                  helperText: _esEdicion
                      ? 'No cambia al consumir o desechar productos.'
                      : 'Existencias iniciales del lote.',
                ),
                validator: (value) {
                  final numero = int.tryParse(value ?? '');

                  if (numero == null || numero <= 0) {
                    return 'Debe ser mayor que cero';
                  }

                  return null;
                },
              ),
              if (_esEdicion)
                TextFormField(
                  controller: _cantidadActual,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Existencias actuales',
                  ),
                  validator: (value) {
                    final numero = int.tryParse(value ?? '');
                    final inicial = int.tryParse(_cantidadInicial.text);

                    if (numero == null ||
                        numero < 0 ||
                        inicial == null ||
                        numero > inicial) {
                      return 'Usa un valor entre 0 y la cantidad inicial';
                    }

                    return null;
                  },
                ),
              if (!_esEdicion)
                TextFormField(
                  controller: _precio,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio unitario (opcional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }

                    final numero = double.tryParse(
                      value.replaceAll(',', '.'),
                    );

                    if (numero == null || numero < 0) {
                      return 'Ingresa un precio válido';
                    }

                    return null;
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.event),
                label: Text(
                  _fechaCaducidad == null
                      ? 'Elegir caducidad'
                      : 'Caduca: ${_formatoFecha(_fechaCaducidad!)}',
                ),
              ),
              if (_esEdicion)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activo,
                  title: const Text('Lote activo'),
                  onChanged: (value) {
                    setState(() => _activo = value);
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SalidaResult {
  final int cantidad;
  final String? motivo;

  const _SalidaResult({
    required this.cantidad,
    required this.motivo,
  });
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
                child: Text(widget.producto),
              ),
              const SizedBox(height: 8),
              Text('Existencias disponibles: ${widget.disponible}'),
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
          child: Text(
            _esDesecho ? 'Confirmar desecho' : 'Confirmar consumo',
          ),
        ),
      ],
    );
  }
}
