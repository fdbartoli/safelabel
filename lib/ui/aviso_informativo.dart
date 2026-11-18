import 'package:flutter/material.dart';

/// Posicionamiento obligatorio en la interfaz (sección 10): la app es
/// informativa, no reemplaza la etiqueta oficial ni la indicación de un
/// profesional de la salud, y el semáforo depende de lo que se pudo leer.
class AvisoInformativo extends StatelessWidget {
  const AvisoInformativo({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              compacto
                  ? 'Herramienta informativa: el semáforo se basa en lo que se '
                        'pudo leer y en la base local. Siempre revisá la etiqueta '
                        'oficial.'
                  : 'SafeLabel es una herramienta informativa. No reemplaza la '
                        'etiqueta oficial del producto ni la indicación de un '
                        'profesional de la salud. El resultado se basa en lo que '
                        'se pudo leer de la etiqueta y en la base local: un '
                        'ingrediente que no aparece no significa que esté ausente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
