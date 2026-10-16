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
    if (mounted) {
      setState(() {
        _categorias = CategoriaDao.obtenerTodos();
      });
    }
  }

  Future<void> _editar([CategoriaDao? categoria]) async {
    final nombre = TextEditingController(text: categoria?.nombre ?? '');
    final descripcion = TextEditingController(
      text: categoria?.descripcion ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(categoria == null ? 'Nueva categoría' : 'Editar categoría'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un nombre'
                    : null,
              ),
              TextFormField(
                controller: descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar == true) {
      final value = CategoriaDao(
        id: categoria?.id,
        nombre: nombre.text.trim(),
        descripcion: descripcion.text.trim(),
      );

      try {
        if (categoria == null) {
          await CategoriaDao.insertar(value);
        } else {
          await CategoriaDao.actualizar(value);
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

    nombre.dispose();
    descripcion.dispose();
  }

  Future<void> _eliminar(CategoriaDao categoria) async {
    final currentContext = context;
    final db = await Conexion().database;
    if (!currentContext.mounted) return;

    final vinculados = Sqflite.firstIntValue(
          await db!.rawQuery(
            'SELECT COUNT(*) FROM producto WHERE id_categoria = ?',
            [categoria.id],
          ),
        ) ??
        0;

    if (vinculados > 0) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text(
            'No se puede eliminar: hay $vinculados productos en esta categoría.',
          ),
        ),
      );
      return;
    }

    if (!currentContext.mounted) return;
    final confirmar = await showDialog<bool>(
      context: currentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${categoria.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await CategoriaDao.eliminar(categoria.id!);
        _recargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen.buildBase(
      context: context,
      title: "Categorías",
      body: SafeArea(
        child: Column(
          children: [
            // 💡 El Expanded evita el error de RenderFlex overflowed por 199,733 px
            Expanded(
              child: FutureBuilder<List<CategoriaDao>>(
                future: _categorias,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categorias = snapshot.data!;
                  if (categorias.isEmpty) {
                    return const Center(child: Text('Aún no hay categorías.'));
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
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _editar,
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