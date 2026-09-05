import 'package:flutter/material.dart';

import '../modelo/ingrediente.dart';
import '../modelo/perfil.dart';
import '../modelo/resultado_analisis.dart';
import 'aviso_informativo.dart';

/// Resultado del análisis en tres bloques, siempre en este orden (sección 5.5):
/// 1) coincidencias con el perfil, 2) no reconocidos, 3) no legibles.
/// Sin bloque de "apto", sin resumen verde (regla 1.4).
class PantallaResultado extends StatelessWidget {
  const PantallaResultado({super.key, required this.resultado});

  final ResultadoAnalisis resultado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hallazgos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AvisoInformativo(compacto: true),
          const SizedBox(height: 16),

          if (resultado.hayLecturaParcial)
            _Callout(
              icon: Icons.center_focus_weak_outlined,
              titulo: 'La lectura fue parcial',
              texto:
                  'Algunas líneas no se leyeron con seguridad. Revisá el bloque '
                  '"No legibles" más abajo y sacá otra foto de esa parte.',
            ),

          _Bloque(
            numero: 1,
            titulo: 'Coincidencias con el perfil',
            vacioTexto:
                'Ninguna coincidencia entre lo que se pudo leer y los perfiles '
                'activos. Esto no significa que el producto sea apto: revisá los '
                'otros dos bloques y la etiqueta oficial.',
            hijos: [
              for (final h in resultado.coincidencias) _TarjetaHallazgo(h),
            ],
          ),

          _Bloque(
            numero: 2,
            titulo: 'No reconocidos',
            subtitulo: resultado.conteoAnalizados,
            vacioTexto: 'Todos los ingredientes leídos están en la base.',
            hijos: [
              for (final n in resultado.noReconocidos) _TarjetaNoReconocido(n),
            ],
          ),

          _Bloque(
            numero: 3,
            titulo: 'No legibles',
            vacioTexto: 'No quedaron líneas sin leer.',
            hijos: [
              for (final l in resultado.noLegibles) _TarjetaNoLegible(l),
            ],
          ),

          if (resultado.notasExcepciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notas (excepciones del CAA)',
                style: Theme.of(context).textTheme.titleMedium),
            for (final n in resultado.notasExcepciones)
              _Callout(
                icon: Icons.rule_outlined,
                titulo: '${n.textoLeido} — ${n.grupoAlergeno}',
                texto: '${n.regla}\n\nFuente: ${n.fuente}',
              ),
          ],

          if (resultado.avisosCruce.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Verificación cruzada con la línea "CONTIENE"',
                style: Theme.of(context).textTheme.titleMedium),
            for (final a in resultado.avisosCruce)
              _Callout(
                icon: a.prioridad == PrioridadCola.alta
                    ? Icons.priority_high_outlined
                    : Icons.compare_arrows_outlined,
                titulo: a.grupoAlergeno == null
                    ? 'Aviso'
                    : 'Declara ${a.grupoAlergeno}',
                texto: a.mensaje,
              ),
          ],

          const SizedBox(height: 16),
          _DeclaracionTextual(resultado: resultado),

          const SizedBox(height: 24),
          Text(
            'Base de conocimiento usada: ${resultado.versionBase}\n'
            'Perfiles: ${resultado.perfilesActivos.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({
    required this.numero,
    required this.titulo,
    required this.hijos,
    required this.vacioTexto,
    this.subtitulo,
  });

  final int numero;
  final String titulo;
  final String? subtitulo;
  final List<Widget> hijos;
  final String vacioTexto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(radius: 13, child: Text('$numero')),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        if (subtitulo != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 2),
            child: Text(subtitulo!,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: 8),
        if (hijos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(vacioTexto,
                style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          ...hijos,
      ],
    );
  }
}

class _TarjetaHallazgo extends StatelessWidget {
  const _TarjetaHallazgo(this.h);
  final HallazgoPerfil h;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fuerte = h.severidadMaxima == Severidad.anafilaxia;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: fuerte ? scheme.errorContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(fuerte ? Icons.warning_amber_rounded : Icons.error_outline,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${h.textoLeido}  →  ${h.grupoAlergeno}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(h.porQue),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Chip('Afecta: ${h.perfilesAfectados.join(", ")}'),
                _Chip(_textoCerteza(h.certeza)),
                if (h.difuso)
                  _Chip('lectura aproximada '
                      '(${(h.similitud * 100).round()}%)'),
                if (h.padre != null) _Chip('dentro de: ${h.padre}'),
                _Chip(_textoOrigen(h.origen)),
              ],
            ),
            if (h.aclaracionCruce != null) ...[
              const SizedBox(height: 8),
              Text(h.aclaracionCruce!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 6),
            Text('Fuente: ${h.fuente}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _textoCerteza(Certeza c) {
    switch (c) {
      case Certeza.seguro:
        return 'siempre implica el alérgeno';
      case Certeza.posible:
        return 'suele implicarlo';
      case Certeza.dependeDeLaFuente:
        return 'depende del origen declarado';
    }
  }

  String _textoOrigen(OrigenHallazgo o) {
    switch (o) {
      case OrigenHallazgo.ingrediente:
        return 'detectado en la lista';
      case OrigenHallazgo.lineaContiene:
        return 'declarado en "CONTIENE"';
      case OrigenHallazgo.ambos:
        return 'lista + "CONTIENE"';
    }
  }
}

class _TarjetaNoReconocido extends StatelessWidget {
  const _TarjetaNoReconocido(this.n);
  final ItemNoReconocido n;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${n.texto}"',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (n.probableErrorOcr && n.candidato != null)
              Text(
                'Se parece a "${n.candidato}". Puede ser un error de lectura: '
                'probá con otra foto más nítida de esta parte.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Text(
                n.advertenciaReforzada
                    ? 'No está en la base. Con un perfil de alergia grave, tratá '
                        'este ingrediente como no resuelto hasta confirmarlo por '
                        'otra vía. Otra foto no lo cambia.'
                    : 'No está en la base. No se puede afirmar ni descartar que '
                        'implique un alérgeno. Otra foto no lo cambia.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (n.padre != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('dentro de: ${n.padre}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaNoLegible extends StatelessWidget {
  const _TarjetaNoLegible(this.l);
  final ItemNoLegible l;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Línea ${l.lineaIndice + 1} · confianza '
                '${(l.confianza * 100).round()}%'),
            const SizedBox(height: 4),
            Text('Se leyó como: "${l.textoParcial}"',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('Sacá otra foto enfocando esta línea, sin reflejo y acercando '
                'un poco el envase.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DeclaracionTextual extends StatelessWidget {
  const _DeclaracionTextual({required this.resultado});
  final ResultadoAnalisis resultado;

  @override
  Widget build(BuildContext context) {
    final d = resultado.declaracion;
    if (!d.hayDeclaracion) {
      return Text('No se leyó una línea "CONTIENE / PUEDE CONTENER".',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lo que dice la etiqueta, textual',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final l in d.lineasContiene)
          Text('· $l', style: Theme.of(context).textTheme.bodyMedium),
        for (final l in d.lineasPuedeContener)
          Text('· $l', style: Theme.of(context).textTheme.bodyMedium),
        if (d.lineasPuedeContener.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '"Puede contener" es una leyenda voluntaria y no estandarizada: '
            'indica riesgo de contacto cruzado durante la elaboración, no que el '
            'ingrediente esté en la receta. Se muestra tal cual, sin interpretarla.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.titulo,
    required this.texto,
  });

  final IconData icon;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(texto, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
