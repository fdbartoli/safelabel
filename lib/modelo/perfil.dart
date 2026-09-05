/// Severidad de una restricción. Importa para el tono de las advertencias:
/// un perfil con anafilaxia debe recibir avisos más firmes ante ingredientes
/// desconocidos que uno de intolerancia leve (sección 4 del CLAUDE.md).
enum Severidad {
  leve,
  moderada,
  anafilaxia;

  static Severidad desdeJson(String? v) {
    switch (v) {
      case 'anafilaxia':
        return Severidad.anafilaxia;
      case 'moderada':
        return Severidad.moderada;
      default:
        return Severidad.leve;
    }
  }

  int get orden => index;
}

class RestriccionPerfil {
  const RestriccionPerfil({
    required this.grupoAlergenoId,
    required this.severidad,
  });

  final String grupoAlergenoId;
  final Severidad severidad;
}

/// Un perfil alimentario activo. En la Etapa 1 se arma en memoria; la
/// persistencia y la compartición llegan en la Etapa 3.
class Perfil {
  const Perfil({required this.nombre, required this.restricciones});

  final String nombre;
  final List<RestriccionPerfil> restricciones;

  Severidad? severidadPara(String grupoAlergenoId) {
    for (final r in restricciones) {
      if (r.grupoAlergenoId == grupoAlergenoId) return r.severidad;
    }
    return null;
  }

  bool restringe(String grupoAlergenoId) => severidadPara(grupoAlergenoId) != null;
}
