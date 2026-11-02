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
  final String tipoCoincidencia;
  final String restriccion;
  final String restriccionVisible;
  final List<EvidenciaConocimiento> evidencias;
}

class ResultadoConsultaConocimiento {
  const ResultadoConsultaConocimiento({
    required this.entrada,
    required this.coincidencias,
  });

  final String entrada;
  final List<CoincidenciaConocimiento> coincidencias;

  bool get encontrado => coincidencias.isNotEmpty;
}
