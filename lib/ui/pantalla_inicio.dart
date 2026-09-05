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
          const SizedBox(height: 8),
          ...perfilesDemo.map((p) {
            return CheckboxListTile(
              value: _activos.contains(p),
              onChanged: (v) => setState(() {
                if (v ?? false) {
                  _activos.add(p);
                } else {
                  _activos.remove(p);
                }
              }),
              title: Text(p.nombre),
              subtitle: Text(_descripcionRestricciones(p)),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            );
          }),
          const SizedBox(height: 24),
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
          Text(
            'Base de conocimiento ${widget.base.version} · '
            '${widget.base.cantidadIngredientes} ingredientes',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.base.atribucion,
            style: Theme.of(context).textTheme.bodySmall,
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
