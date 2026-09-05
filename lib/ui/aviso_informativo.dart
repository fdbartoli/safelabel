import 'package:flutter/material.dart';

/// Posicionamiento obligatorio en la interfaz (sección 10): la app es
/// informativa, no reemplaza la etiqueta oficial ni la indicación de un
/// profesional de la salud, y no emite veredicto de aptitud (regla 1.4).
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
                  ? 'Herramienta informativa. No dice si un producto es apto: '
                      'muestra hallazgos para que decidas vos. Siempre revisá la '
                      'etiqueta oficial.'
                  : 'SafeLabel es una herramienta informativa. No reemplaza la '
                      'etiqueta oficial del producto ni la indicación de un '
                      'profesional de la salud, y no dice si un alimento es apto '
                      'o seguro: te muestra los hallazgos y la decisión es tuya. '
                      'Un ingrediente que no aparece no significa que esté ausente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
