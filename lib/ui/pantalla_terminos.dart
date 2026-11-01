import 'package:flutter/material.dart';

import '../cuenta/terminos_condiciones.dart';

/// Muestra los términos y condiciones vigentes.
class PantallaTerminos extends StatelessWidget {
  const PantallaTerminos({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(TerminosCondiciones.titulo)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(
                  'Versión ${TerminosCondiciones.version}, vigente desde el '
                  '${TerminosCondiciones.vigenteDesde}.',
                  style: textos.bodySmall,
                ),
                for (final seccion in TerminosCondiciones.secciones) ...[
                  const SizedBox(height: 20),
                  Text(seccion.titulo, style: textos.titleMedium),
                  const SizedBox(height: 6),
                  Text(seccion.texto, style: textos.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
