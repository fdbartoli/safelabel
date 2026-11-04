import '../ocr/linea_ocr.dart';

/// Diagnóstico de una lectura: qué devolvió el OCR y cómo lo procesó el
/// pipeline, paso a paso. Sirve para ver, ante un resultado raro, si falló la
/// foto, el OCR o el análisis. No cambia el resultado: solo lo explica.
class DiagnosticoOcr {
  const DiagnosticoOcr({
    required this.lineas,
    required this.umbralConfianza,
    required this.items,
    required this.lineasContiene,
    required this.lineasPuedeContener,
    required this.versionBase,
  });

  /// Todas las líneas tal como las devolvió el OCR, en orden.
  final List<LineaOcr> lineas;

  /// Debajo de esta confianza la línea se trata como no legible.
  final double umbralConfianza;

  /// Cómo quedó separado el texto en ingredientes y qué encontró el matcher.
  final List<ItemDiagnostico> items;

  final List<String> lineasContiene;
  final List<String> lineasPuedeContener;
  final String versionBase;

  bool esLegible(LineaOcr l) => l.confianza >= umbralConfianza;

  int get lineasSinConfianza =>
      lineas.where((l) => !l.confianzaInformada).length;

  int get cantidadBloques =>
      lineas.isEmpty ? 0 : lineas.map((l) => l.bloque).toSet().length;

  /// Informe en texto plano, para copiar y pegar (WhatsApp, un issue, un
  /// archivo de fixtures).
  String aTexto() {
    final b = StringBuffer()
      ..writeln('SafeLabel · diagnóstico de lectura')
      ..writeln('Base de conocimiento: $versionBase')
      ..writeln()
      ..writeln('== Texto del OCR: ${lineas.length} líneas en '
          '$cantidadBloques bloques ==');
    if (lineasSinConfianza > 0) {
      b.writeln('(el OCR no informó confianza en $lineasSinConfianza líneas: '
          'se asumió alta)');
    }
    for (final l in lineas) {
      final conf = l.confianzaInformada
          ? '${(l.confianza * 100).round()}%'
          : 's/d';
      final marca = esLegible(l) ? '' : ' [NO LEGIBLE]';
      b.writeln('#${l.indice + 1} b${l.bloque + 1} $conf$marca | ${l.texto}');
    }
    b
      ..writeln()
      ..writeln('== Ingredientes separados: ${items.length} ==');
    for (final i in items) {
      b.writeln('- ${i.textoOriginal}${i.padre != null ? ' (dentro de ${i.padre})' : ''}'
          ' → ${i.descripcion}');
    }
    if (lineasContiene.isNotEmpty || lineasPuedeContener.isNotEmpty) {
      b
        ..writeln()
        ..writeln('== Declaración de alérgenos ==');
      for (final l in lineasContiene) {
        b.writeln('contiene: $l');
      }
      for (final l in lineasPuedeContener) {
        b.writeln('puede contener: $l');
      }
    }
    return b.toString();
  }
}

enum EstadoItem {
  /// Coincidencia exacta con un nombre o sinónimo de la base.
  exacto,

  /// Coincidencia por similitud (posible typo del OCR).
  difuso,

  /// El ítem contiene un término con alérgeno ("harina de trigo tipo 000").
  contiene,

  /// No está en la base, pero se parece a algo: probable error de OCR.
  desconocidoParecido,

  /// No está en la base y no se parece a nada.
  desconocido,
}

class ItemDiagnostico {
  const ItemDiagnostico({
    required this.textoOriginal,
    required this.textoNormalizado,
    required this.estado,
    this.padre,
    this.ins,
    this.terminoBase,
    this.grupoAlergeno,
    this.similitud,
  });

  final String textoOriginal;
  final String textoNormalizado;
  final EstadoItem estado;
  final String? padre;
  final String? ins;

  /// Término de la base con el que coincidió o al que se parece.
  final String? terminoBase;

  /// Grupo de alérgeno del término de la base. `null` si no tiene.
  final String? grupoAlergeno;

  final double? similitud;

  String get descripcion {
    final pct = similitud == null ? '' : ' ${(similitud! * 100).round()}%';
    final grupo = grupoAlergeno == null ? 'sin alérgeno' : grupoAlergeno!;
    switch (estado) {
      case EstadoItem.exacto:
        return 'exacto: "$terminoBase" ($grupo)';
      case EstadoItem.difuso:
        return 'parecido$pct a "$terminoBase" ($grupo)';
      case EstadoItem.contiene:
        return 'contiene "$terminoBase" ($grupo)';
      case EstadoItem.desconocidoParecido:
        return 'no reconocido; se parece$pct a "$terminoBase"';
      case EstadoItem.desconocido:
        return 'no reconocido';
    }
  }
}
