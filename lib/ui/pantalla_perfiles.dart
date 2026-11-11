import 'package:flutter/material.dart';

import '../datos/base_conocimiento.dart';
import '../datos/repositorio_perfiles.dart';
import '../modelo/perfil.dart';
import 'avatar.dart';
import 'editor_perfil.dart';

/// Lista de perfiles guardados en el dispositivo, con alta, edición y borrado.
class PantallaPerfiles extends StatefulWidget {
  const PantallaPerfiles({
    super.key,
    required this.repositorio,
    required this.base,
  });

  final RepositorioPerfiles repositorio;
  final BaseConocimiento base;

  @override
  State<PantallaPerfiles> createState() => _PantallaPerfilesState();
}

class _PantallaPerfilesState extends State<PantallaPerfiles> {
  List<Perfil>? _perfiles;

  /// Perfil cuya tarjeta está pidiendo confirmación de borrado. La
  /// confirmación queda en la propia tarjeta, no en un diálogo.
  String? _confirmandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfiles = await widget.repositorio.obtenerTodos();
    if (mounted) setState(() => _perfiles = perfiles);
  }

  Future<void> _abrirEditor([Perfil? perfil]) async {
    setState(() => _confirmandoId = null);
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => EditorPerfil(
          repositorio: widget.repositorio,
          base: widget.base,
          perfil: perfil,
        ),
      ),
    );
    await _cargar();
  }

  Future<void> _eliminar(Perfil perfil) async {
    try {
      await widget.repositorio.eliminar(perfil.id);
    } on PerfilNoEncontrado {
      // Ya no estaba: el resultado buscado es el mismo.
    }
    _confirmandoId = null;
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final perfiles = _perfiles;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo perfil'),
      ),
      body: perfiles == null
          ? const Center(child: CircularProgressIndicator())
          : perfiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay perfiles. Creá uno para empezar.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final p in perfiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _confirmandoId == p.id
                        ? _tarjetaConfirmacion(p)
                        : _tarjeta(p),
                  ),
              ],
            ),
    );
  }

  Widget _tarjeta(Perfil p) {
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Avatar(semilla: p.semillaAvatar, tamano: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: texto.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    describirRestricciones(p, widget.base),
                    style: texto.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _abrirEditor(p),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _confirmandoId = p.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaConfirmacion(Perfil p) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Eliminar "${p.nombre}"? Se borran también sus restricciones. '
              'No se puede deshacer.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _confirmandoId = null),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: () => _eliminar(p),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
