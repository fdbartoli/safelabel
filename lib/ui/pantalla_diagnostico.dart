import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelo/diagnostico_ocr.dart';
import 'tema.dart';

/// Panel "Ver texto leído": muestra lo que devolvió el OCR y cómo lo separó y
/// emparejó el pipeline. Es una herramienta de diagnóstico para probar el OCR
/// sobre etiquetas reales; no reemplaza ni modifica los tres bloques.
///
/// Usa el tema neutro de resultados: muestra grupos de alérgenos y no debe
/// llevar verde (regla 1.4).
class PantallaDiagnostico extends StatelessWidget {
  const PantallaDiagnostico({super.key, required this.diagnostico});

  final DiagnosticoOcr diagnostico;

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: diagnostico.aTexto()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texto leído copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: temaResultado,
      child: Builder(builder: _construir),
    );
  }

  Widget _construir(BuildContext context) {
    final tema = Theme.of(context);
    final d = diagnostico;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Texto leído'),
        actions: [
          TextButton.icon(
            onPressed: () => _copiar(context),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Lo que devolvió el OCR y cómo lo procesó el análisis. Copialo '
            'para guardarlo junto con la foto de la etiqueta.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _Resumen(diagnostico: d),

          _Titulo('Texto del OCR (${d.lineas.length} líneas)'),
          if (d.lineas.isEmpty)
            Text('El OCR no devolvió texto.', style: tema.textTheme.bodyMedium)
          else
            for (final l in d.lineas)
              _FilaLinea(
                indice: l.indice,
                bloque: l.bloque,
                texto: l.texto,
                confianza: l.confianzaInformada ? l.confianza : null,
                legible: d.esLegible(l),
              ),

          _Titulo('Ingredientes separados (${d.items.length})'),
          if (d.items.isEmpty)
            Text(
              'No se separó ningún ingrediente. Puede que la foto no incluya '
              'la lista, o que el OCR no haya leído el encabezado.',
              style: tema.textTheme.bodyMedium,
            )
          else
            for (final i in d.items) _FilaItem(item: i),

          if (d.lineasContiene.isNotEmpty ||
              d.lineasPuedeContener.isNotEmpty) ...[
            const _Titulo('Declaración de alérgenos leída'),
            for (final l in d.lineasContiene)
              Text('contiene: $l', style: tema.textTheme.bodyMedium),
            for (final l in d.lineasPuedeContener)
              Text('puede contener: $l', style: tema.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.diagnostico});
  final DiagnosticoOcr diagnostico;

  @override
  Widget build(BuildContext context) {
    final d = diagnostico;
    final tema = Theme.of(context);
    final sinConf = d.lineasSinConfianza;
    final noLegibles = d.lineas.where((l) => !d.esLegible(l)).length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.lineas.length} líneas en ${d.cantidadBloques} bloques · '
            '$noLegibles no legibles · ${d.items.length} ingredientes',
            style: tema.textTheme.bodyMedium,
          ),
          if (sinConf > 0) ...[
            const SizedBox(height: 6),
            Text(
              'El OCR no informó la confianza de $sinConf líneas y se asumió '
              'alta: esas líneas nunca se marcan como no legibles.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _FilaLinea extends StatelessWidget {
  const _FilaLinea({
    required this.indice,
    required this.bloque,
    required this.texto,
    required this.confianza,
    required this.legible,
  });

  final int indice;
  final int bloque;
  final String texto;

  /// `null` si el OCR no la informó.
  final double? confianza;
  final bool legible;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final conf = confianza == null
        ? 'confianza s/d'
        : 'confianza ${(confianza! * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${indice + 1} · bloque ${bloque + 1} · $conf'
            '${legible ? '' : ' · NO LEGIBLE'}',
            style: tema.textTheme.labelSmall?.copyWith(
              color: legible ? tema.colorScheme.onSurfaceVariant : tema.colorScheme.error,
            ),
          ),
          SelectableText(
            texto,
            style: tema.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({required this.item});
  final ItemDiagnostico item;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final conocido = item.estado == EstadoItem.exacto ||
        item.estado == EstadoItem.difuso ||
        item.estado == EstadoItem.contiene;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            conocido ? Icons.link : Icons.help_outline,
            size: 18,
            color: tema.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.textoOriginal,
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.padre != null ? 'dentro de ${item.padre} · ' : ''}'
                  '${item.descripcion}',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
