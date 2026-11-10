import 'package:flutter/material.dart';

import '../datos/base_conocimiento.dart';
import '../datos/repositorio_perfiles.dart';
import '../modelo/grupo_alergeno.dart';
import '../modelo/perfil.dart';

/// Alta y edición de un perfil.
///
/// Las restricciones se eligen de los grupos de [base], nunca como texto
/// libre: si alguien escribiera "lactosa" y el grupo es "leche", el análisis
/// no cruzaría nada y no habría ningún aviso.
///
/// La severidad se elige con un desplegable por grupo y no con casillas: una
/// tilde al lado de "leche" se puede leer como "leche: OK" (regla 1.4).
class EditorPerfil extends StatefulWidget {
  const EditorPerfil({
    super.key,
    required this.repositorio,
    required this.base,
    this.perfil,
  });

  final RepositorioPerfiles repositorio;
  final BaseConocimiento base;

  /// `null` para crear uno nuevo.
  final Perfil? perfil;

  @override
  State<EditorPerfil> createState() => _EditorPerfilState();
}

class _EditorPerfilState extends State<EditorPerfil> {
  late final TextEditingController _nombre;

  /// grupo → severidad. Conserva el orden original de las restricciones; las
  /// nuevas se agregan al final.
  final Map<String, Severidad> _severidades = {};

  String? _error;
  bool _guardando = false;

  bool get _esNuevo => widget.perfil == null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.perfil?.nombre ?? '');
    for (final r in widget.perfil?.restricciones ?? const []) {
      _severidades[r.grupoAlergenoId] = r.severidad;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  /// Restricciones guardadas con un grupo que ya no está en la base (por
  /// ejemplo, si un release la cambió). No cruzan con nada: se muestran para
  /// que se quiten, en vez de dejarlas escondidas.
  List<String> get _gruposHuerfanos => [
    for (final id in _severidades.keys)
      if (widget.base.grupo(id) == null) id,
  ];

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final restricciones = [
      for (final e in _severidades.entries)
        RestriccionPerfil(grupoAlergenoId: e.key, severidad: e.value),
    ];
    try {
      if (_esNuevo) {
        await widget.repositorio.crear(
          Perfil(nombre: _nombre.text, restricciones: restricciones),
        );
      } else {
        await widget.repositorio.actualizar(
          widget.perfil!.copiarCon(
            nombre: _nombre.text,
            restricciones: restricciones,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorValidacionPerfil catch (e) {
      setState(() => _error = e.mensaje);
    } on PerfilNoEncontrado {
      setState(() => _error = 'Este perfil ya no existe.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final huerfanos = _gruposHuerfanos;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.perfil?.esPersonal == true
              ? 'Editar Mi perfil'
              : (_esNuevo ? 'Nuevo perfil' : 'Editar perfil'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.perfil?.esPersonal == true)
            Text('Mi perfil', style: texto.titleMedium)
          else
            TextField(
              key: const Key('nombre_perfil'),
              controller: _nombre,
              maxLength: largoMaximoNombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
          const SizedBox(height: 12),
          Text('Restricciones', style: texto.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Elegí la severidad para cada grupo que este perfil necesita '
            'evitar. Los grupos son los alérgenos de declaración obligatoria '
            'del Código Alimentario Argentino.',
            style: texto.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final id in huerfanos) _filaHuerfana(id, scheme, texto),
          for (final g in widget.base.grupos.values) _filaGrupo(g, texto),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _filaGrupo(GrupoAlergeno g, TextTheme texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(g.nombre),
        // Para trigo: "trigo, avena, cebada y/o centeno", que es lo que se lee
        // en la etiqueta (sección 5.3).
        subtitle: g.textoEtiqueta != g.nombre ? Text(g.textoEtiqueta) : null,
        trailing: DropdownButton<Severidad?>(
          key: Key('severidad_${g.id}'),
          value: _severidades[g.id],
          underline: const SizedBox.shrink(),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin restricción')),
            for (final s in Severidad.values)
              DropdownMenuItem(value: s, child: Text(nombreSeveridad(s))),
          ],
          onChanged: (s) => setState(() {
            if (s == null) {
              _severidades.remove(g.id);
            } else {
              _severidades[g.id] = s;
            }
          }),
        ),
      ),
    );
  }

  Widget _filaHuerfana(String id, ColorScheme scheme, TextTheme texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '"$id" ya no existe en la base de conocimiento y no se cruza '
              'con ningún análisis. Quitalo y elegí el grupo que corresponda.',
              style: texto.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _severidades.remove(id)),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }
}

String nombreSeveridad(Severidad s) => switch (s) {
  Severidad.leve => 'Leve',
  Severidad.moderada => 'Moderada',
  Severidad.anafilaxia => 'Anafilaxia',
};

/// "leche (anafilaxia) · maní (leve)", con los nombres de la base. Un grupo
/// que la base ya no tiene se señala en vez de mostrarse como si nada.
String describirRestricciones(Perfil p, BaseConocimiento base) {
  if (p.restricciones.isEmpty) return 'Sin restricciones';
  return p.restricciones
      .map((r) {
        final nombre =
            base.grupo(r.grupoAlergenoId)?.nombre ??
            '${r.grupoAlergenoId} (no existe en la base)';
        return '$nombre (${nombreSeveridad(r.severidad).toLowerCase()})';
      })
      .join(' · ');
}
