import '../pipeline/verificacion_cruzada.dart';
import 'ingrediente.dart';
import 'perfil.dart';

/// De dónde salió un hallazgo del bloque 1.
enum OrigenHallazgo {
  /// Match del ingrediente contra la base.
  ingrediente,

  /// Solo la línea "CONTIENE" lo declara (la base no lo tenía).
  lineaContiene,

  /// Ambas señales coinciden.
  ambos,
}

enum PrioridadCola { normal, alta }

/// Bloque 1: coincidencia con un perfil activo.
class HallazgoPerfil {
  const HallazgoPerfil({
    required this.textoLeido,
    required this.nombreEnBase,
    required this.grupoAlergeno,
    required this.porQue,
    required this.certeza,
    required this.difuso,
    required this.similitud,
    required this.perfilesAfectados,
    required this.severidadMaxima,
    required this.fuente,
    required this.origen,
    this.padre,
    this.aclaracionCruce,
  });

  /// Lo que se leyó en la etiqueta.
  final String textoLeido;

  /// Nombre canónico en la base (puede diferir si el match fue difuso).
  final String nombreEnBase;

  /// Nombre del grupo de alérgeno para mostrar.
  final String grupoAlergeno;

  /// Explicación pregenerada. Nunca se redacta en el dispositivo (regla 1.1).
  final String porQue;

  final Certeza certeza;
  final bool difuso;
  final double similitud;

  /// Nombres de los perfiles activos a los que afecta.
  final List<String> perfilesAfectados;

  final Severidad severidadMaxima;

  final String fuente;
  final OrigenHallazgo origen;

  /// Ingrediente contenedor si vino de un anidado.
  final String? padre;

  /// Aclaración de la verificación cruzada (sección 5.3, fila 3): el ingrediente
  /// marca alérgeno pero la línea CONTIENE no lo declara.
  final String? aclaracionCruce;
}

/// Bloque 2: ítem leído con claridad pero ausente de la base. Otra foto no
/// cambia nada (regla: no colapsar UNKNOWN con UNREADABLE).
class ItemNoReconocido {
  const ItemNoReconocido({
    required this.texto,
    required this.probableErrorOcr,
    required this.advertenciaReforzada,
    this.candidato,
    this.padre,
  });

  final String texto;

  /// `true` si se parece mucho a algo de la base: quizás sea error de OCR y
  /// convenga otra foto.
  final bool probableErrorOcr;

  /// `true` si algún perfil activo tiene severidad anafilaxia: el aviso por
  /// desconocidos se refuerza.
  final bool advertenciaReforzada;

  final String? candidato;
  final String? padre;
}

/// Bloque 3: línea que el OCR no leyó con confianza. Otra foto puede resolverla.
class ItemNoLegible {
  const ItemNoLegible({
    required this.lineaIndice,
    required this.textoParcial,
    required this.confianza,
  });

  final int lineaIndice;
  final String textoParcial;
  final double confianza;
}

/// Nota informativa por una excepción del CAA (sección 5.4). No es un veredicto.
class NotaExcepcion {
  const NotaExcepcion({
    required this.textoLeido,
    required this.grupoAlergeno,
    required this.regla,
    required this.fuente,
  });

  final String textoLeido;
  final String grupoAlergeno;
  final String regla;
  final String fuente;
}

/// Aviso de la verificación cruzada con la línea CONTIENE (sección 5.3).
class AvisoCruzado {
  const AvisoCruzado({
    required this.mensaje,
    required this.prioridad,
    this.grupoAlergeno,
  });

  final String mensaje;
  final PrioridadCola prioridad;
  final String? grupoAlergeno;
}

/// Resultado del análisis de una etiqueta.
///
/// Regla 1.4: NO existe un campo de aptitud, ni resumen, ni indicador verde.
/// La app muestra hallazgos y deja la decisión en la persona.
class ResultadoAnalisis {
  const ResultadoAnalisis({
    required this.versionBase,
    required this.perfilesActivos,
    required this.coincidencias,
    required this.noReconocidos,
    required this.noLegibles,
    required this.notasExcepciones,
    required this.avisosCruce,
    required this.declaracion,
    required this.totalItems,
    required this.itemsAnalizados,
    required this.severidadMaxima,
  });

  /// Versión de la base usada. Se registra por trazabilidad (sección 10).
  final String versionBase;

  final List<String> perfilesActivos;

  /// Bloque 1.
  final List<HallazgoPerfil> coincidencias;

  /// Bloque 2.
  final List<ItemNoReconocido> noReconocidos;

  /// Bloque 3.
  final List<ItemNoLegible> noLegibles;

  final List<NotaExcepcion> notasExcepciones;
  final List<AvisoCruzado> avisosCruce;

  /// Línea CONTIENE / PUEDE CONTENER, textual (regla 1.7).
  final DeclaracionAlergenos declaracion;

  final int totalItems;

  /// Cuántos ítems se pudieron analizar. Para el conteo "11 de 12" del bloque 2.
  final int itemsAnalizados;

  final Severidad? severidadMaxima;

  bool get hayLecturaParcial => noLegibles.isNotEmpty;

  /// Texto para el conteo del bloque 2.
  String get conteoAnalizados =>
      '$itemsAnalizados de $totalItems ingredientes analizados';
}
