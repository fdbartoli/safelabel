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

enum EstadoConsultaConocimiento { matched, recognized, unknown }

class CoincidenciaConocimiento {
  const CoincidenciaConocimiento({
    required this.denominacion,
    required this.idioma,
    required this.concepto,
    required this.tipoCoincidencia,
    required this.restriccion,
    required this.restriccionVisible,
    required this.evidencias,
  });

  final String denominacion;
  final String idioma;
  final String concepto;
  final String? tipoCoincidencia;
  final String? restriccion;
  final String? restriccionVisible;
  final List<EvidenciaConocimiento> evidencias;

  bool get tieneRestriccion => restriccion != null;
}

class ResultadoConsultaConocimiento {
  const ResultadoConsultaConocimiento({
    required this.entrada,
    required this.estado,
    required this.coincidencias,
  });

  final String entrada;
  final EstadoConsultaConocimiento estado;
  final List<CoincidenciaConocimiento> coincidencias;

  bool get encontrado => estado != EstadoConsultaConocimiento.unknown;
  bool get relacionado => estado == EstadoConsultaConocimiento.matched;
  bool get reconocidoSinRelacion =>
      estado == EstadoConsultaConocimiento.recognized;
}
