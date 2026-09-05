/// Grado de certeza de que un ingrediente implique el grupo de alérgeno indicado.
///
/// Espejo del campo `certainty` del modelo de datos (sección 4 del CLAUDE.md).
enum Certeza {
  /// Siempre implica el alérgeno. Ej.: "caseinato de sodio" → leche.
  seguro,

  /// Suele implicarlo, pero depende del producto. Ej.: "aroma" → puede tener leche.
  posible,

  /// Depende de la fuente declarada. Ej.: "lecitina" (soja vs. girasol).
  dependeDeLaFuente;

  static Certeza desdeJson(String? valor) {
    switch (valor) {
      case 'certain':
      case 'seguro':
        return Certeza.seguro;
      case 'possible':
      case 'posible':
        return Certeza.posible;
      case 'depends_on_source':
      case 'depende_de_la_fuente':
        return Certeza.dependeDeLaFuente;
      default:
        return Certeza.posible;
    }
  }
}

/// Tipo de sinónimo, para poder explicar de dónde viene la coincidencia.
enum TipoSinonimo {
  /// Nombre comercial o de fantasía.
  comercial,

  /// Nombre técnico o químico, incluidos los números INS.
  tecnico,

  /// Variante frecuente de error de OCR (ej.: "caselnato").
  varianteOcr;

  static TipoSinonimo desdeJson(String? valor) {
    switch (valor) {
      case 'commercial':
      case 'comercial':
        return TipoSinonimo.comercial;
      case 'ocr_variant':
      case 'variante_ocr':
        return TipoSinonimo.varianteOcr;
      default:
        return TipoSinonimo.tecnico;
    }
  }
}

class Sinonimo {
  const Sinonimo({
    required this.texto,
    required this.textoNormalizado,
    required this.tipo,
  });

  final String texto;
  final String textoNormalizado;
  final TipoSinonimo tipo;
}

/// Una entrada de la base de conocimiento local de la Etapa 1.
///
/// IMPORTANTE (reglas 1.1 y 1.6): este objeto describe una determinación tomada
/// por una fuente humana o normativa, nunca por un LLM en runtime. El campo
/// [fuente] es obligatorio: sin `source_ref` no entra a la base.
class Ingrediente {
  const Ingrediente({
    required this.nombreCanonico,
    required this.nombreNormalizado,
    required this.grupoAlergenoId,
    required this.certeza,
    required this.explicacion,
    required this.fuente,
    this.sinonimos = const [],
  });

  /// Nombre de referencia: "caseinato de sodio".
  final String nombreCanonico;

  /// [nombreCanonico] pasado por el normalizador (minúsculas, sin acentos).
  final String nombreNormalizado;

  /// A qué [GrupoAlergeno] pertenece su origen. `null` significa que el término
  /// está en la base con fuente citable y **no** está asociado a ninguno de los
  /// alérgenos de declaración obligatoria. No es un veredicto de aptitud (regla
  /// 1.4) ni contradice la regla 1.3: acá el término sí fue encontrado.
  final String? grupoAlergenoId;

  bool get implicaAlergeno => grupoAlergenoId != null;

  final Certeza certeza;

  /// Texto pregenerado en lenguaje claro. Nunca se genera en el dispositivo.
  final String explicacion;

  /// De dónde salió la determinación (OFF, CAA art. 235 séptimo, curado manual).
  final String fuente;

  final List<Sinonimo> sinonimos;

  factory Ingrediente.desdeJson(
    Map<String, dynamic> json,
    String Function(String) normalizar,
  ) {
    final sinonimosJson = (json['sinonimos'] as List<dynamic>? ?? const []);
    return Ingrediente(
      nombreCanonico: json['nombre_canonico'] as String,
      nombreNormalizado: normalizar(json['nombre_canonico'] as String),
      grupoAlergenoId: json['grupo_alergeno_id'] as String?,
      certeza: Certeza.desdeJson(json['certeza'] as String?),
      explicacion: json['explicacion'] as String,
      fuente: json['fuente'] as String,
      sinonimos: [
        for (final s in sinonimosJson)
          Sinonimo(
            texto: s['texto'] as String,
            textoNormalizado: normalizar(s['texto'] as String),
            tipo: TipoSinonimo.desdeJson(s['tipo'] as String?),
          ),
      ],
    );
  }

  @override
  String toString() => 'Ingrediente($nombreCanonico → $grupoAlergenoId)';
}

/// Excepción del CAA modelada explícitamente (sección 5.4).
///
/// Ej.: "maltodextrina" derivada de trigo está exenta de declarar gluten.
/// Un LLM genérico marcaría "maltodextrina" como gluten; la base debe tener
/// la excepción como regla.
class Excepcion {
  const Excepcion({
    required this.nombreNormalizado,
    required this.grupoAlergenoId,
    required this.regla,
    required this.fuente,
  });

  /// Nombre normalizado del ingrediente al que aplica la excepción.
  final String nombreNormalizado;

  /// Grupo de alérgeno del que queda exento.
  final String grupoAlergenoId;

  /// Texto de la regla, para mostrar y para trazabilidad.
  final String regla;

  final String fuente;

  factory Excepcion.desdeJson(
    Map<String, dynamic> json,
    String Function(String) normalizar,
  ) {
    return Excepcion(
      nombreNormalizado: normalizar(json['nombre_ingrediente'] as String),
      grupoAlergenoId: json['grupo_alergeno_id'] as String,
      regla: json['regla'] as String,
      fuente: json['fuente'] as String,
    );
  }
}
