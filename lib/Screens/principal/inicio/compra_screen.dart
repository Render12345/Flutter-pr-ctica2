
import 'package:flutter/material.dart';
import 'package:practica_2/Dao/compra_dao.dart';
import 'package:practica_2/config/conexion.dart';

class CompraScreen extends StatefulWidget {
  final List<Map<String, Object?>> productos;

  const CompraScreen({
    super.key,
    required this.productos,
  });

  @override
  State<CompraScreen> createState() => _CompraScreenState();
}

class _CompraScreenState extends State<CompraScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, Object?>> _tiendas = [];
  int? _idTienda;

  bool _cargando = true;
  bool _guardando = false;

  late DateTime _fechaIngreso;
  late List<TextEditingController> _precios;
  late List<DateTime?> _caducidades;

  @override
  void initState() {
    super.initState();

    final hoy = DateTime.now();
    _fechaIngreso = DateTime(hoy.year, hoy.month, hoy.day);

    _precios = List.generate(
      widget.productos.length,
      (_) => TextEditingController(),
    );

    _caducidades = List.generate(
      widget.productos.length,
      (_) => null,
    );

    _cargarTiendas();
  }

  @override
  void dispose() {
    for (final controller in _precios) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarTiendas() async {
    try {
      final db = await Conexion().database;

      final tiendas = await db!.query(
        'tienda',
        orderBy: 'nombre COLLATE NOCASE',
      );

      if (!mounted) return;

      setState(() {
        _tiendas = tiendas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _cargando = false);
      _mensaje('No se pudieron cargar las tiendas: $e');
    }
  }

  void _mensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  String _fechaTexto(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String _fechaBD(DateTime fecha) {
    return '${fecha.year}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> _seleccionarFechaIngreso() {
    final hoy = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: _fechaIngreso,
      firstDate: DateTime(2000),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
    );
  }

  Future<void> _elegirFechaIngreso() async {
    final fecha = await _seleccionarFechaIngreso();

    if (fecha != null && mounted) {
      setState(() => _fechaIngreso = fecha);
    }
  }

  Future<void> _elegirCaducidad(int index) async {
  final hoy = DateTime.now();

  final fecha = await showDatePicker(
    context: context,
    initialDate: _caducidades[index] ?? hoy,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  if (fecha != null && mounted) {
    setState(() {
      _caducidades[index] = fecha;
    });
  }
}

  Future<void> _confirmar() async {
    if (_cargando || _guardando) return;

    if (_tiendas.isEmpty) {
      _mensaje('Primero registra una tienda.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    for (int i = 0; i < _caducidades.length; i++) {
      final caducidad = _caducidades[i];
      final nombre = widget.productos[i]['nombre'] ?? 'Producto';

      if (caducidad == null) {
        _mensaje('Selecciona la caducidad de $nombre.');
        return;
      }

      if (caducidad.isBefore(_fechaIngreso)) {
        _mensaje(
          'La caducidad de $nombre no puede ser anterior '
          'a la fecha de ingreso.',
        );
        return;
      }
    }

    setState(() => _guardando = true);

    try {
      final hoy = DateTime.now();
      final fechaCompra = DateTime(hoy.year, hoy.month, hoy.day);

      final productosPreparados = <Map<String, Object?>>[];

      for (int i = 0; i < widget.productos.length; i++) {
        final producto = widget.productos[i];

        productosPreparados.add({
          'idProducto': (producto['idProducto'] as num).toInt(),
          'cantidad': (producto['cantidad'] as num).toInt(),
          'precioUnitario': double.parse(_precios[i].text.trim()),
          'fechaIngreso': _fechaBD(_fechaIngreso),
          'fechaCaducidad': _fechaBD(_caducidades[i]!),
        });
      }

      final registros = await CompraDao().registrarCompra(
        idTienda: _idTienda!,
        fechaCompra: _fechaBD(fechaCompra),
        productos: productosPreparados,
      );

      if (!mounted) return;

      // Regresa a Inicio indicando que la compra fue exitosa.
      Navigator.of(context).pop(registros);
    } catch (e) {
      if (!mounted) return;

      _mensaje('No se pudo registrar la compra: $e');
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fechaCompra = DateTime(hoy.year, hoy.month, hoy.day);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('resources/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Registrar compra'),
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromARGB(255, 6, 63, 109),
          leading: IconButton(
            tooltip: 'Regresar a Inicio',
            icon: const Icon(Icons.arrow_back),
            onPressed: _guardando
                ? null
                : () => Navigator.of(context).pop(),
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _tiendas.isEmpty
                ? Center(
                    child: Card(
                      margin: const EdgeInsets.all(20),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.store_outlined,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No hay tiendas registradas.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Registra una tienda antes de realizar '
                              'una compra.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Regresar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 650,
                        ),
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Información de la compra',
                                        style: Theme.of(context)
                                            .textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<int>(
                                        value: _idTienda,
                                        isExpanded: true,
                                        decoration:
                                            const InputDecoration(
                                          labelText: 'Tienda',
                                          prefixIcon:
                                              Icon(Icons.store),
                                          border:
                                              OutlineInputBorder(),
                                        ),
                                        items: _tiendas.map((tienda) {
                                          return DropdownMenuItem<int>(
                                            value: (tienda['id'] as num)
                                                .toInt(),
                                            child: Text(
                                              tienda['nombre']
                                                      as String? ??
                                                  'Tienda',
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _guardando
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _idTienda = value;
                                                });
                                              },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Selecciona una tienda';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.event_available,
                                        ),
                                        title:
                                            const Text('Fecha de compra'),
                                        subtitle: Text(
                                          _fechaTexto(fechaCompra),
                                        ),
                                        trailing: const Icon(
                                          Icons.lock_outline,
                                        ),
                                      ),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.inventory_2_outlined,
                                        ),
                                        title:
                                            const Text('Fecha de ingreso'),
                                        subtitle: Text(
                                          _fechaTexto(_fechaIngreso),
                                        ),
                                        trailing: const Icon(
                                          Icons.calendar_month,
                                        ),
                                        onTap: _guardando
                                            ? null
                                            : _elegirFechaIngreso,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Productos y lotes',
                                  style: Theme.of(context)
                                      .textTheme.titleLarge,
                                ),
                              ),
                              ...List.generate(
                                widget.productos.length,
                                (i) {
                                  final producto = widget.productos[i];
                                  final nombre =
                                      producto['nombre'] as String? ??
                                          'Producto';
                                  final cantidad =
                                      (producto['cantidad'] as num)
                                          .toInt();
                                  final unidad =
                                      producto['unidad'] as String? ?? '';

                                  return Card(
                                    margin: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.inventory_2_outlined,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  nombre,
                                                  style: Theme.of(context)
                                                      .textTheme.titleMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Cantidad: $cantidad $unidad',
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _precios[i],
                                            enabled: !_guardando,
                                            keyboardType:
                                                const TextInputType
                                                    .numberWithOptions(
                                              decimal: true,
                                            ),
                                            decoration:
                                                const InputDecoration(
                                              labelText:
                                                  'Precio por unidad',
                                              prefixText: '\$ ',
                                              border:
                                                  OutlineInputBorder(),
                                            ),
                                            validator: (value) {
                                              final precio =
                                                  double.tryParse(
                                                (value ?? '').trim(),
                                              );

                                              if (precio == null ||
                                                  !precio.isFinite ||
                                                  precio < 0) {
                                                return 'Ingresa un precio válido';
                                              }

                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.event_busy,
                                            ),
                                            title:
                                                const Text('Caducidad'),
                                            subtitle: Text(
                                              _caducidades[i] == null
                                                  ? 'Selecciona la fecha'
                                                  : _fechaTexto(
                                                      _caducidades[i]!,
                                                    ),
                                            ),
                                            trailing: const Icon(
                                              Icons.calendar_month,
                                            ),
                                            onTap: _guardando
                                                ? null
                                                : () =>
                                                    _elegirCaducidad(i),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _guardando || _cargando
                                    ? null
                                    : _confirmar,
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(
                                  _guardando
                                      ? 'Registrando compra...'
                                      : 'Confirmar compra',
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
