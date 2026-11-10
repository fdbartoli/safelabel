import 'package:flutter/material.dart';

import '../cuenta/servicio_cuenta.dart';
import '../conocimiento/catalogo_conocimiento.dart';
import '../datos/base_conocimiento.dart';
import '../datos/repositorio_conocimiento.dart';
import '../datos/repositorio_perfiles.dart';
import '../modelo/perfil.dart';
import 'aviso_informativo.dart';
import 'controlador_tema.dart';
import 'avatar.dart';
import 'editor_perfil.dart';
import 'pantalla_analisis_texto.dart';
import 'pantalla_captura.dart';
import 'pantalla_consulta_conocimiento.dart';
import 'pantalla_mi_cuenta.dart';
import 'pantalla_perfiles.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({
    super.key,
    required this.base,
    required this.repositorio,
    required this.conocimiento,
    required this.catalogo,
    this.servicioCuenta,
    this.controladorTema,
  });

  final BaseConocimiento base;
  final RepositorioPerfiles repositorio;
  final RepositorioConocimiento conocimiento;
  final CatalogoConocimiento catalogo;

  /// Si está, la barra superior muestra el acceso a "Mi cuenta" (HU03 a HU05).
  final ServicioCuenta? servicioCuenta;

  /// Si está, la barra superior muestra el botón de modo claro / oscuro.
  final ControladorTema? controladorTema;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<Perfil> _todos = const [];

  /// La selección se guarda por id, no por identidad de objeto: cada lectura
  /// del repositorio devuelve objetos nuevos, y un `Set<Perfil>` dejaría de
  /// reconocerlos después de recargar.
  Set<String> _idsActivos = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todos = await widget.repositorio.obtenerTodos();
    final activos = await widget.repositorio.obtenerActivos();
    if (!mounted) return;
    setState(() {
      _todos = todos;
      _idsActivos = {for (final p in activos) p.id};
      _cargando = false;
    });
  }

  Future<void> _alternar(Perfil p) async {
    setState(() {
      if (!_idsActivos.remove(p.id)) _idsActivos.add(p.id);
    });
    try {
      await widget.repositorio.marcarActivos(Set.of(_idsActivos));
    } on PerfilNoEncontrado {
      // El perfil se borró en otra pantalla: se recarga lo que hay de verdad.
      await _cargar();
    }
  }

  Future<void> _administrarPerfiles() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaPerfiles(
          repositorio: widget.repositorio,
          base: widget.base,
        ),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final perfiles = [
      for (final p in _todos)
        if (_idsActivos.contains(p.id)) p,
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeLabel'),
        actions: [
          if (widget.controladorTema case final controlador?)
            BotonModoTema(controlador: controlador),
          if (widget.servicioCuenta case final servicio?)
            // Se redibuja cuando cambia la cuenta (por ejemplo, el avatar).
            ListenableBuilder(
              listenable: servicio,
              builder: (context, _) {
                final cuenta = servicio.cuentaActual();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    key: const Key('boton_mi_cuenta'),
                    tooltip: 'Mi cuenta',
                    icon: cuenta == null
                        ? const Icon(Icons.account_circle_outlined)
                        : Avatar(semilla: cuenta.semillaAvatar, tamano: 34),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PantallaMiCuenta(servicio: servicio),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AvisoInformativo(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Perfiles activos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _administrarPerfiles,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Administrar'),
              ),
            ],
          ),
          Text(
            'El análisis se cruza con estos perfiles.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_todos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay perfiles guardados. Tocá "Administrar" para crear uno.',
              ),
            ),
          ..._todos.map((p) {
            final activo = _idsActivos.contains(p.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: activo
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _alternar(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        // Avatar con una marca de activo, al estilo de
                        // "¿Quién está mirando?".
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Opacity(
                              opacity: activo ? 1 : 0.55,
                              child: Avatar(
                                semilla: p.semillaAvatar,
                                tamano: 44,
                              ),
                            ),
                            Positioned(
                              right: -5,
                              bottom: -5,
                              child: Icon(
                                activo
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 20,
                                color: activo ? scheme.primary : scheme.outline,
                                shadows: [
                                  Shadow(color: scheme.surface, blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                describirRestricciones(p, widget.base),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: perfiles.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaCaptura(
                        base: widget.base,
                        catalogo: widget.catalogo,
                        perfilesActivos: perfiles,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Escanear etiqueta'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: perfiles.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaAnalisisTexto(
                        base: widget.base,
                        catalogo: widget.catalogo,
                        perfilesActivos: perfiles,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.text_fields_outlined),
            label: const Text('Analizar texto pegado (sin cámara)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PantallaConsultaConocimiento(
                  repositorio: widget.conocimiento,
                ),
              ),
            ),
            icon: const Icon(Icons.manage_search_outlined),
            label: const Text('Consultar ingrediente'),
          ),
          if (perfiles.isEmpty && !_cargando)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Elegí al menos un perfil para empezar.'),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Base de conocimiento ${widget.catalogo.version} · '
                  '${widget.catalogo.conceptos.length} conceptos',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.base.atribucion,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
