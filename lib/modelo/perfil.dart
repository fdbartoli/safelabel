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

/// Un perfil alimentario. Se persiste en el SQLite del dispositivo a través de
/// `RepositorioPerfiles`; la propiedad corresponde a una cuenta local.
class Perfil {
  const Perfil({
    this.id = '',
    this.usuarioId,
    required this.nombre,
    required this.restricciones,
  });

  /// Identificador que asigna el repositorio al guardar. Vacío mientras el
  /// perfil no fue guardado (los perfiles armados en memoria, como en los
  /// tests del análisis, no lo necesitan).
  final String id;

  /// Null solo para perfiles heredados pendientes o valores aún no guardados.
  final String? usuarioId;

  final String nombre;
  final List<RestriccionPerfil> restricciones;

  Perfil copiarCon({
    String? id,
    String? usuarioId,
    String? nombre,
    List<RestriccionPerfil>? restricciones,
  }) {
    return Perfil(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      restricciones: restricciones ?? this.restricciones,
    );
  }

  Severidad? severidadPara(String grupoAlergenoId) {
    for (final r in restricciones) {
      if (r.grupoAlergenoId == grupoAlergenoId) return r.severidad;
    }
    return null;
  }

  bool restringe(String grupoAlergenoId) =>
      severidadPara(grupoAlergenoId) != null;
}
