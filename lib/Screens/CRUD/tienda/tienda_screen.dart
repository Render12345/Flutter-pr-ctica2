import 'package:flutter/material.dart';
import 'package:practica_2/Dao/tienda_dao.dart';
import 'package:practica_2/config/conexion.dart';
import 'package:practica_2/components/base_screen.dart';
import 'package:sqflite/sqflite.dart';

class TiendaScreen extends StatefulWidget {
  const TiendaScreen({super.key});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  late Future<List<TiendaDao>> _tiendas;

  @override
  void initState() {
    super.initState();
    _tiendas = TiendaDao.obtenerTodos();
  }

  void _recargar() {
    if (mounted) {
      setState(() {
        _tiendas = TiendaDao.obtenerTodos();
      });
    }
  }

  Future<void> _editar([TiendaDao? tienda]) async {
    final nombre = TextEditingController(text: tienda?.nombre ?? '');
    final direccion = TextEditingController(text: tienda?.direccion ?? '');
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tienda == null ? 'Nueva tienda' : 'Editar tienda'),
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
                controller: direccion,
                decoration: const InputDecoration(labelText: 'Dirección'),
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
      final value = TiendaDao(
        id: tienda?.id,
        nombre: nombre.text.trim(),
        direccion: direccion.text.trim(),
      );
      try {
        if (tienda == null) {
          await TiendaDao.insertar(value);
        } else {
          await TiendaDao.actualizar(value);
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
    direccion.dispose();
  }

  Future<void> _eliminar(TiendaDao tienda) async {
    final currentContext = context;
    final db = await Conexion().database;
    if (!currentContext.mounted) return;
    final vinculados =
        Sqflite.firstIntValue(
          await db!.rawQuery(
            'SELECT (SELECT COUNT(*) FROM producto WHERE id_tienda = ?) + (SELECT COUNT(*) FROM historial WHERE id_tienda = ?)',
            [tienda.id, tienda.id],
          ),
        ) ??
        0;
    if (vinculados > 0) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar: la tienda aparece en productos o compras.',
          ),
        ),
      );
      return;
    }
    if (!currentContext.mounted) return;
    final confirmar = await showDialog<bool>(
      context: currentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tienda'),
        content: Text('¿Eliminar "${tienda.nombre}"?'),
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
    if (!mounted) return;
    if (confirmar == true) {
      try {
        await TiendaDao.eliminar(tienda.id!);
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
      title: "Tiendas",
      body: SafeArea(
        child: FutureBuilder<List<TiendaDao>>(
        future: _tiendas,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tiendas = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: tiendas.isEmpty
                    ? const Center(
                        child: Text('Aún no hay tiendas registradas.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: tiendas.length,
                        itemBuilder: (context, index) {
                          final tienda = tiendas[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.store_outlined),
                              ),
                              title: Text(tienda.nombre ?? ''),
                              subtitle: Text(
                                tienda.direccion?.isNotEmpty == true
                                    ? tienda.direccion!
                                    : 'Sin dirección',
                              ),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _editar(tienda),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () => _eliminar(tienda),
                                    icon: const Icon(Icons.delete_outline),
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
                    label: const Text('Agregar tienda'),
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
