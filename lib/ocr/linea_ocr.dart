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
    this.bloque = 0,
    this.confianzaInformada = true,
  });

  final String texto;

  /// Confianza reportada por el motor, en [0, 1].
  final double confianza;

  /// Posición de la línea dentro de la captura (para señalar cuál falló).
  final int indice;

  /// Bloque de texto del OCR al que pertenece la línea. Sirve para ver si el
  /// motor partió la lista de ingredientes en columnas o pedazos.
  final int bloque;

  /// `false` si el motor no informó confianza y se asumió alta (pasa casi
  /// siempre con ML Kit en Android). En ese caso el triage no puede marcar
  /// la línea como no legible.
  final bool confianzaInformada;

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
