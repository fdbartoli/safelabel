class EvidenciaConocimiento {
  const EvidenciaConocimiento({
    required this.fuente,
    required this.tituloFuente,
    required this.url,
    required this.fragmento,
  });

  final String fuente;
  final String tituloFuente;
  final String url;
  final String fragmento;
}

/// Estados de una consulta, alineados con los de la sección 5.1:
///  - [matched]: está en la base y tiene relación con alguna restricción.
///  - [recognized]: está en la base y no registra relación con las
///    restricciones incorporadas (no significa seguro, regla 1.3).
///  - [parecido]: no está, pero se parece a un término de la base:
///    probablemente un error de escritura. No se afirma la coincidencia.
///  - [unknown]: no está y no se parece a nada.
enum EstadoConsultaConocimiento { matched, recognized, parecido, unknown }

/// Cómo coincidió la consulta con el término de la base. Es el mismo criterio
/// que usa el análisis de una etiqueta (matcher).
enum TipoCoincidenciaConsulta {
  /// Igual a un nombre o sinónimo de la base (sin importar tildes ni
  /// mayúsculas).
  exacta,

  /// Contiene un término con restricción: "harina de trigo tipo 000"
  /// contiene "harina de trigo".
  contiene,

  /// Se parece lo suficiente a un término de la base (posible error de
  /// escritura o de OCR).
  aproximada,
}

class CoincidenciaConocimiento {
  const CoincidenciaConocimiento({
    required this.denominacion,
    required this.concepto,
    required this.tipoCoincidencia,
    required this.restriccion,
    required this.restriccionVisible,
    required this.evidencias,
    this.idioma,
    this.coincidencia = TipoCoincidenciaConsulta.exacta,
    this.similitud = 1,
  });

  /// Término de la base con el que coincidió, tal como está guardado.
  final String denominacion;

  /// Idioma de la denominación, si se conoce.
  final String? idioma;

  /// Nombre canónico del concepto.
  final String concepto;

  /// Tipo de relación con la restricción en la base: 'DIRECT' o 'RELATED'.
  final String? tipoCoincidencia;
  final String? restriccion;
  final String? restriccionVisible;
  final List<EvidenciaConocimiento> evidencias;

  final TipoCoincidenciaConsulta coincidencia;

  /// 1.0 salvo en la coincidencia aproximada.
  final double similitud;

  bool get tieneRestriccion => restriccion != null;
}

class ResultadoConsultaConocimiento {
  const ResultadoConsultaConocimiento({
    required this.entrada,
    required this.estado,
    required this.coincidencias,
    this.sugerencia,
    this.similitudSugerencia,
  });

  final String entrada;
  final EstadoConsultaConocimiento estado;
  final List<CoincidenciaConocimiento> coincidencias;

  /// En [EstadoConsultaConocimiento.parecido]: el término de la base al que
  /// se parece la consulta.
  final String? sugerencia;
  final double? similitudSugerencia;

  bool get encontrado =>
      estado == EstadoConsultaConocimiento.matched ||
      estado == EstadoConsultaConocimiento.recognized;
  bool get relacionado => estado == EstadoConsultaConocimiento.matched;
  bool get reconocidoSinRelacion =>
      estado == EstadoConsultaConocimiento.recognized;
}
