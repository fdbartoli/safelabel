import 'package:flutter/material.dart';

import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import 'aviso_informativo.dart';
import 'pantalla_analisis_texto.dart';
import 'pantalla_captura.dart';
import 'perfiles_demo.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.base});

  final BaseConocimiento base;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final Set<Perfil> _activos = {perfilesDemo.first};

  @override
  Widget build(BuildContext context) {
    final perfiles = _activos.toList();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('SafeLabel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AvisoInformativo(),
          const SizedBox(height: 20),
          Text('Perfiles activos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'El análisis se cruza con estos perfiles.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ...perfilesDemo.map((p) {
            final activo = _activos.contains(p);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: activo ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() {
                    if (activo) {
                      _activos.remove(p);
                    } else {
                      _activos.add(p);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          activo ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: activo ? scheme.primary : scheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(_descripcionRestricciones(p),
                                  style: Theme.of(context).textTheme.bodySmall),
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
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PantallaCaptura(
                        base: widget.base,
                        perfilesActivos: perfiles,
                      ),
                    )),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Escanear etiqueta'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: perfiles.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PantallaAnalisisTexto(
                        base: widget.base,
                        perfilesActivos: perfiles,
                      ),
                    )),
            icon: const Icon(Icons.text_fields_outlined),
            label: const Text('Analizar texto pegado (sin cámara)'),
          ),
          if (perfiles.isEmpty)
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
                  'Base de conocimiento ${widget.base.version} · '
                  '${widget.base.cantidadIngredientes} ingredientes',
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

  String _descripcionRestricciones(Perfil p) {
    return p.restricciones
        .map((r) => '${r.grupoAlergenoId} (${r.severidad.name})')
        .join(' · ');
  }
}
