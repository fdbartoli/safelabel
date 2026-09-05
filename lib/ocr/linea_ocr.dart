/// Una línea reconocida por el OCR, con su confianza.
///
/// Regla 1.2: el LLM nunca ve la imagen. El OCR corre en el dispositivo y
/// entrega texto + bounding box + confianza por línea. En la Etapa 1 solo
/// usamos texto y confianza.
class LineaOcr {
  const LineaOcr({
    required this.texto,
    required this.confianza,
    this.indice = 0,
  });

  final String texto;

  /// Confianza reportada por el motor, en [0, 1].
  final double confianza;

  /// Posición de la línea dentro de la captura (para señalar cuál falló).
  final int indice;

  @override
  String toString() =>
      'LineaOcr(#$indice, conf=${confianza.toStringAsFixed(2)}, "$texto")';
}

/// Resultado del OCR sobre una captura completa.
class LecturaOcr {
  const LecturaOcr(this.lineas);

  final List<LineaOcr> lineas;

  /// Texto completo, en orden, sin filtrar por confianza.
  String get textoCompleto => lineas.map((l) => l.texto).join('\n');
}
