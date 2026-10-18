
import 'package:flutter/material.dart';
import 'package:practica_2/Dao/categoria_dao.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/components/base_screen.dart';
import 'package:sqflite/sqflite.dart';

class CategoriaScreen extends StatefulWidget {
  const CategoriaScreen({super.key});

  @override
  State<CategoriaScreen> createState() => _CategoriaScreenState();
}

class _CategoriaScreenState extends State<CategoriaScreen> {
  late Future<List<CategoriaDao>> _categorias;

  @override
  void initState() {
    super.initState();
    _categorias = CategoriaDao.obtenerTodos();
  }

  void _recargar() {
    if (!mounted) return;

    setState(() {
      _categorias = CategoriaDao.obtenerTodos();
    });
  }

  Future<void> _editar([CategoriaDao? categoria]) async {
    final resultado = await showDialog<CategoriaDao>(
      context: context,
      builder: (_) => _CategoriaDialog(categoria: categoria),
    );

    if (resultado == null || !mounted) return;

    try {
      if (categoria == null) {
        await CategoriaDao.insertar(resultado);
      } else {
        await CategoriaDao.actualizar(resultado);
      }

      _recargar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _eliminar(CategoriaDao categoria) async {
    final db = await Conexion().database;
    if (!mounted) return;

    final vinculados = Sqflite.firstIntValue(
          await db!.rawQuery(
            'SELECT COUNT(*) FROM producto WHERE id_categoria = ?',
            [categoria.id],
          ),
        ) ??
        0;

    if (!mounted) return;

    if (vinculados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se puede eliminar: hay $vinculados '
            'productos en esta categoría.',
          ),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${categoria.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await CategoriaDao.eliminar(categoria.id!);
      _recargar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: 'Categorías',
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<CategoriaDao>>(
                future: _categorias,
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

                  final categorias = snapshot.data!;

                  if (categorias.isEmpty) {
                    return const Center(
                      child: Text('Aún no hay categorías.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: categorias.length,
                    itemBuilder: (context, index) {
                      final categoria = categorias[index];

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.category_outlined),
                          ),
                          title: Text(categoria.nombre ?? ''),
                          subtitle: Text(
                            categoria.descripcion?.isNotEmpty == true
                                ? categoria.descripcion!
                                : 'Sin descripción',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () => _editar(categoria),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _eliminar(categoria),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar categoría'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriaDialog extends StatefulWidget {
  final CategoriaDao? categoria;

  const _CategoriaDialog({this.categoria});

  @override
  State<_CategoriaDialog> createState() => _CategoriaDialogState();
}

class _CategoriaDialogState extends State<_CategoriaDialog> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _nombre = TextEditingController(
      text: widget.categoria?.nombre ?? '',
    );

    _descripcion = TextEditingController(
      text: widget.categoria?.descripcion ?? '',
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final resultado = CategoriaDao(
      id: widget.categoria?.id,
      nombre: _nombre.text.trim(),
      descripcion: _descripcion.text.trim(),
    );

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.categoria == null
            ? 'Nueva categoría'
            : 'Editar categoría',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombre,
              autofocus: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
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
