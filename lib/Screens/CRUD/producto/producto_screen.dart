import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:practica_2/Dao/categoria_dao.dart';
import 'package:practica_2/Dao/producto_dao.dart';
import 'package:practica_2/Dao/tienda_dao.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/components/base_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ProductoScreen extends StatefulWidget {
  const ProductoScreen({super.key});

  @override
  State<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends State<ProductoScreen> {
  late Future<List<Map<String, Object?>>> _productos;

  @override
  void initState() {
    super.initState();
    _productos = _obtenerProductos();
  }

  Future<List<Map<String, Object?>>> _obtenerProductos() async {
    final db = await Conexion().database;
    return db!.rawQuery('''
      SELECT p.*, c.nombre AS categoria, t.nombre AS tienda,
        COALESCE(SUM(CASE WHEN l.activo = 1 THEN l.cantidad ELSE 0 END), 0) AS stock
      FROM producto p
      LEFT JOIN categoria c ON c.id = p.id_categoria
      LEFT JOIN tienda t ON t.id = p.id_tienda
      LEFT JOIN lote l ON l.id_producto = p.id
      GROUP BY p.id ORDER BY p.nombre COLLATE NOCASE
    ''');
  }

  void _recargar() => setState(() => _productos = _obtenerProductos());

  Future<String?> _elegirImagen() async {
    final seleccion = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (seleccion == null) return null;
    final carpeta = await getApplicationDocumentsDirectory();
    final nombre =
        'producto_${DateTime.now().microsecondsSinceEpoch}${path.extension(seleccion.path)}';
    final copia = await File(seleccion.path)
        .copy(path.join(carpeta.path, nombre));
    return copia.path;
  }

  Future<void> _editar([ProductoDao? producto]) async {
    final categorias = await CategoriaDao.obtenerTodos();
    final tiendas = await TiendaDao.obtenerTodos();
    if (!mounted) return;
    final nombre = TextEditingController(text: producto?.nombre ?? '');
    final marca = TextEditingController(text: producto?.marca ?? '');
    final unidad = TextEditingController(text: producto?.unidad ?? 'unidades');
    final minimo = TextEditingController(text: '${producto?.stockMinimo ?? 0}');
    final imagen = TextEditingController(text: producto?.imagenRuta ?? '');
    int? categoriaSeleccionada = producto?.idCategoria;
    int? tiendaSeleccionada = producto?.idTienda;
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(producto == null ? 'Nuevo producto' : 'Editar producto'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombre,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ingresa un nombre'
                          : null,
                    ),
                    TextFormField(
                      controller: marca,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                    TextFormField(
                      controller: unidad,
                      decoration: const InputDecoration(
                        labelText: 'Unidad de medida',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ingresa una unidad'
                          : null,
                    ),
                    TextFormField(
                      controller: minimo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock mínimo',
                      ),
                      validator: (value) =>
                          int.tryParse(value ?? '') == null ||
                              int.parse(value!) < 0
                          ? 'Ingresa un entero igual o mayor a 0'
                          : null,
                    ),
                    TextFormField(
                      controller: imagen,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Imagen del producto',
                        hintText: 'Opcional',
                        suffixIcon: IconButton(
                          tooltip: 'Elegir imagen de galería',
                          onPressed: () async {
                            try {
                              final seleccion = await _elegirImagen();
                              if (seleccion != null) {
                                imagen.text = seleccion;
                                setDialogState(() {});
                              }
                            } catch (error) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se pudo cargar la imagen: $error',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                        ),
                      ),
                    ),
                    if (imagen.text.isNotEmpty &&
                        File(imagen.text).existsSync())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Image.file(
                          File(imagen.text),
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    DropdownButtonFormField<int?>(
                      value: categoriaSeleccionada,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin categoría'),
                        ),
                        ...categorias.map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.id,
                            child: Text(item.nombre ?? ''),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => categoriaSeleccionada = value),
                    ),
                    DropdownButtonFormField<int?>(
                      value: tiendaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Tienda habitual',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin tienda'),
                        ),
                        ...tiendas.map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.id,
                            child: Text(item.nombre ?? ''),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tiendaSeleccionada = value),
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
                if (formKey.currentState!.validate())
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (guardar == true) {
      final value = ProductoDao(
        id: producto?.id,
        idCategoria: categoriaSeleccionada,
        nombre: nombre.text.trim(),
        marca: marca.text.trim(),
        unidad: unidad.text.trim(),
        stockMinimo: int.parse(minimo.text),
        imagenRuta: imagen.text.trim().isEmpty ? null : imagen.text.trim(),
        idTienda: tiendaSeleccionada,
      );
      if (producto == null) {
        await ProductoDao.insertar(value);
      } else {
        await ProductoDao.actualizar(value);
      }
      _recargar();
    }
    nombre.dispose();
    marca.dispose();
    unidad.dispose();
    minimo.dispose();
    imagen.dispose();
  }

  Future<void> _eliminar(Map<String, Object?> producto) async {
    final db = await Conexion().database;
    if (!mounted) return;
    final asociados =
        Sqflite.firstIntValue(
          await db!.rawQuery(
            'SELECT (SELECT COUNT(*) FROM lote WHERE id_producto = ?) + (SELECT COUNT(*) FROM historial WHERE id_producto = ?) + (SELECT COUNT(*) FROM alertas WHERE id_producto = ?)',
            [producto['id'], producto['id'], producto['id']],
          ),
        ) ??
        0;
    if (asociados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar: el producto tiene lotes o historial.',
          ),
        ),
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${producto['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmar == true) {
      await ProductoDao.eliminar((producto['id'] as num).toInt());
      if (mounted) _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.m_getBase(
      context: context,
      title: "Productos",
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _productos,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final productos = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: productos.isEmpty
                    ? const Center(
                        child: Text('Aún no hay productos registrados.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final item = productos[index];
                          final rutaImagen = item['imagen_ruta'] as String?;
                          return Card(
                            child: ListTile(
                              leading:
                                  rutaImagen != null &&
                                      rutaImagen.isNotEmpty &&
                                      File(rutaImagen).existsSync()
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(rutaImagen),
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const CircleAvatar(
                                      child: Icon(Icons.inventory_2_outlined),
                                    ),
                              title: Text(item['nombre'] as String? ?? ''),
                              subtitle: Text(
                                '${item['marca'] ?? 'Sin marca'} · ${item['categoria'] ?? 'Sin categoría'}\nStock: ${item['stock']} ${item['unidad'] ?? ''} · Tienda: ${item['tienda'] ?? 'Sin asignar'}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit')
                                    _editar(ProductoDao.fromMap(item));
                                  if (value == 'delete') _eliminar(item);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
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
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar producto'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
