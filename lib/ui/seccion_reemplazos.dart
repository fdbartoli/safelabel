import 'package:flutter/material.dart';

import '../modelo/resultado_analisis.dart';
import '../sugerencias/gestor_reemplazos.dart';
import 'tema.dart';

/// Sección de sustitutos (sección 5.6). Vive debajo de los tres bloques y solo
/// se crea si hay coincidencias. El LLM se llama recién cuando la persona toca
/// "Sugerir sustitutos": el resultado nunca espera a la IA.
///
/// Usa el tema neutro de la pantalla de resultado: sin verde, sin íconos de
/// aprobación (regla 1.4). Los sustitutos se presentan como ideas para buscar.
class SeccionReemplazos extends StatefulWidget {
  const SeccionReemplazos({
    super.key,
    required this.gestor,
    required this.resultado,
  });

  final GestorReemplazos gestor;
  final ResultadoAnalisis resultado;

  @override
  State<SeccionReemplazos> createState() => _SeccionReemplazosState();
}

enum _Estado { inicial, cargando, listo, error, sinConfigurar }

class _SeccionReemplazosState extends State<SeccionReemplazos> {
  _Estado _estado = _Estado.inicial;
  ResultadoReemplazos? _resultado;

  Future<void> _sugerir() async {
    if (!widget.gestor.configurado) {
      setState(() => _estado = _Estado.sinConfigurar);
      return;
    }
    setState(() => _estado = _Estado.cargando);
    try {
      final r = await widget.gestor.obtener(widget.resultado);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _estado = _Estado.listo;
      });
    } catch (_) {
      // Sin conexión, timeout o rechazo del modelo: se avisa y se puede
      // reintentar. Los tres bloques no cambian.
      if (mounted) setState(() => _estado = _Estado.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // El botón es una acción, no un hallazgo: lleva el verde pastel de la
    // marca. Las tarjetas de hallazgos siguen sin verde (regla 1.4).
    final marca = temaApp.colorScheme;
    final boton = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: marca.primaryContainer,
          foregroundColor: marca.onPrimaryContainer,
        ),
        onPressed: _estado == _Estado.cargando ? null : _sugerir,
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Sugerir sustitutos'),
      ),
    );

    switch (_estado) {
      case _Estado.inicial:
        return Padding(padding: const EdgeInsets.only(top: 2), child: boton);

      case _Estado.cargando:
        return _Contenedor(
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Buscando sustitutos…',
                  style: tema.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );

      case _Estado.sinConfigurar:
        return _Contenedor(
          child: Text(
            'La conexión con la IA todavía no está configurada. Por ahora no '
            'se pueden sugerir sustitutos.',
            style: tema.textTheme.bodyMedium,
          ),
        );

      case _Estado.error:
        return _Contenedor(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No se pudieron obtener sustitutos (sin conexión o error de la '
                'IA). Los hallazgos de arriba no cambian.',
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              boton,
            ],
          ),
        );

      case _Estado.listo:
        final r = _resultado!;
        return _Contenedor(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sustitutos para buscar',
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sugeridos por IA. No están verificados: escaneá la etiqueta '
                'del sustituto antes de consumirlo.',
                style: tema.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (r.sugerencias.isEmpty)
                Text(
                  'La IA no propuso sustitutos que no choquen con tus perfiles.',
                  style: tema.textTheme.bodyMedium,
                )
              else
                for (final s in r.sugerencias)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${s.nombre}',
                          style: tema.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s.motivo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 2),
                            child: Text(
                              s.motivo,
                              style: tema.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
              if (r.descartadas.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Se descartaron ${r.descartadas.length} sugerencia(s) que '
                  'chocaban con tus perfiles: '
                  '${r.descartadas.map((d) => '${d.nombre} (${d.grupoAlergeno})').join(', ')}.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}

class _Contenedor extends StatelessWidget {
  const _Contenedor({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
