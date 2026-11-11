import 'package:flutter/material.dart';

import '../compartir/servicio_compartir_restricciones.dart';
import '../datos/base_conocimiento.dart';
import '../datos/repositorio_perfiles.dart';
import '../modelo/perfil.dart';
import 'editor_perfil.dart';
import 'pantalla_compartir_restricciones.dart';
import 'pantalla_escanear_restricciones.dart';

/// Lista de perfiles guardados en el dispositivo, con alta, edición, borrado
/// y selección para compartir.
class PantallaPerfiles extends StatefulWidget {
  const PantallaPerfiles({
    super.key,
    required this.repositorio,
    required this.base,
    required this.nombrePropietario,
    required this.apellidoPropietario,
  });

  final RepositorioPerfiles repositorio;
  final BaseConocimiento base;
  final String nombrePropietario;
  final String apellidoPropietario;

  @override
  State<PantallaPerfiles> createState() => _PantallaPerfilesState();
}

class _PantallaPerfilesState extends State<PantallaPerfiles> {
  ServicioCompartirRestricciones get _compartir =>
      ServicioCompartirRestricciones(
        repositorio: widget.repositorio,
        gruposValidos: widget.base.grupos.keys.toSet(),
        nombrePropietario: widget.nombrePropietario,
        apellidoPropietario: widget.apellidoPropietario,
      );
  List<Perfil>? _perfiles;
  final Set<String> _seleccionados = {};

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
    perfiles.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    if (!mounted) return;
    setState(() {
      _perfiles = perfiles;
      _seleccionados.retainAll({for (final p in perfiles) p.id});
    });
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
    _seleccionados.remove(perfil.id);
    _confirmandoId = null;
    await _cargar();
  }

  Future<void> _escanear() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaEscanearRestricciones(
          servicio: _compartir,
          base: widget.base,
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  void _alternarSeleccion(Perfil perfil) {
    setState(() {
      if (!_seleccionados.remove(perfil.id)) _seleccionados.add(perfil.id);
    });
  }

  void _alternarTodos() {
    final perfiles = _perfiles;
    if (perfiles == null) return;
    setState(() {
      if (_seleccionados.length == perfiles.length) {
        _seleccionados.clear();
      } else {
        _seleccionados.addAll(perfiles.map((p) => p.id));
      }
    });
  }

  Future<void> _compartirSeleccionados() async {
    final perfiles = _perfiles;
    if (perfiles == null) return;
    final elegidos = [
      for (final perfil in perfiles)
        if (_seleccionados.contains(perfil.id)) perfil,
    ];
    if (elegidos.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaCompartirRestricciones(
          servicio: _compartir,
          base: widget.base,
          perfiles: elegidos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfiles = _perfiles;
    final todosSeleccionados =
        perfiles != null &&
        perfiles.isNotEmpty &&
        _seleccionados.length == perfiles.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfiles'),
        actions: [
          if (perfiles != null && perfiles.isNotEmpty)
            IconButton(
              onPressed: _alternarTodos,
              tooltip: todosSeleccionados
                  ? 'Quitar selección'
                  : 'Seleccionar todos',
              icon: Icon(
                todosSeleccionados
                    ? Icons.deselect_outlined
                    : Icons.select_all_outlined,
              ),
            ),
          IconButton(
            onPressed: _seleccionados.isEmpty ? null : _compartirSeleccionados,
            tooltip: 'Compartir perfiles seleccionados',
            icon: const Icon(Icons.qr_code),
          ),
          IconButton(
            onPressed: _escanear,
            tooltip: 'Escanear perfiles',
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
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
                Text(
                  _seleccionados.isEmpty
                      ? 'Marcá los perfiles que querés compartir.'
                      : '${_seleccionados.length} de ${perfiles.length} '
                            '${_seleccionados.length == 1 ? 'perfil seleccionado' : 'perfiles seleccionados'}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
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
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          children: [
            Checkbox(
              key: ValueKey('seleccionar_${p.id}'),
              value: _seleccionados.contains(p.id),
              onChanged: (_) => _alternarSeleccion(p),
              semanticLabel: 'Seleccionar ${p.nombre} para compartir',
            ),
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
