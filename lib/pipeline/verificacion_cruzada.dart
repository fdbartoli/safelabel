import '../datos/base_conocimiento.dart';
import 'normalizador.dart';

/// Paso 6 del Flujo B: lectura de la linea "CONTIENE / PUEDE CONTENER".
///
/// El Art. 235 septimo obliga a declarar los alergenos despues de la lista de
/// ingredientes con la formula `CONTIENE` + alergeno o `CONTIENE DERIVADOS DE`
/// + alergeno. En etiquetas argentinas los cereales con gluten se declaran como
/// "trigo, avena, cebada y/o centeno", **no "gluten"** (seccion 5.3).
///
/// Esta lectura da una segunda senal independiente del analisis de ingredientes.
/// Regla 1.7: "PUEDE CONTENER" se reporta textual, no se interpreta como juicio.
class DeclaracionAlergenos {
  const DeclaracionAlergenos({
    required this.contiene,
    required this.puedeContener,
    required this.lineasContiene,
    required this.lineasPuedeContener,
    required this.tokensNoMapeados,
  });

  /// Ids de grupo declarados con "CONTIENE" (declaracion firme).
  final Set<String> contiene;

  /// Ids de grupo mencionados en "PUEDE CONTENER" (trazas; no es juicio).
  final Set<String> puedeContener;

  /// Texto textual de las lineas "CONTIENE", para mostrar sin reinterpretar.
  final List<String> lineasContiene;

  /// Texto textual de las lineas "PUEDE CONTENER".
  final List<String> lineasPuedeContener;

  /// Tokens de la declaracion que no se pudieron mapear a un grupo conocido.
  final List<String> tokensNoMapeados;

  bool get hayDeclaracion =>
      contiene.isNotEmpty ||
      puedeContener.isNotEmpty ||
      lineasContiene.isNotEmpty ||
      lineasPuedeContener.isNotEmpty;

  static const vacia = DeclaracionAlergenos(
    contiene: {},
    puedeContener: {},
    lineasContiene: [],
    lineasPuedeContener: [],
    tokensNoMapeados: [],
  );
}

class VerificacionCruzada {
  VerificacionCruzada(this.base) {
    _tokenAGrupo = _construirIndiceTokens();
  }

  final BaseConocimiento base;
  static const _normalizador = Normalizador();

  late final Map<String, String> _tokenAGrupo;

  static final RegExp _inicioContiene = RegExp(
    r'^contiene(?:\s+derivados?\s+de)?\s*:?\s*',
  );
  static final RegExp _inicioPuede = RegExp(
    r'^(?:puede\s+contener\s+trazas\s+de|puede\s+contener|'
    r'contiene\s+trazas\s+de|'
    r'elaborado\s+en\s+(?:una\s+)?(?:linea|planta|establecimiento|fabrica)\s+que\s+'
    r'(?:tambien\s+)?(?:procesa|elabora|contiene|utiliza))\s*:?\s*',
  );
  static final RegExp _noContiene = RegExp(r'^no\s+contiene\b');

  Map<String, String> _construirIndiceTokens() {
    final mapa = <String, String>{};
    for (final grupo in base.grupos.values) {
      void reg(String t) {
        final n = _normalizador.normalizarTexto(t);
        if (n.isNotEmpty) mapa.putIfAbsent(n, () => grupo.id);
      }

      reg(grupo.id);
      reg(grupo.nombre);
      for (final t in _partirEnumeracion(grupo.textoEtiqueta)) {
        reg(t);
      }
      // Puente explicito: si una etiqueta dijera "contiene gluten" (algunas lo
      // hacen), se entiende como el grupo de los cereales. Buscar "gluten" en la
      // lista de ingredientes seguiria siendo un error (seccion 5.3).
      final etiquetaNorm = _normalizador.normalizarTexto(grupo.textoEtiqueta);
      if (grupo.id == 'trigo' || etiquetaNorm.contains('trigo')) {
        mapa.putIfAbsent('gluten', () => grupo.id);
      }
    }
    return mapa;
  }

  /// Divide "trigo, avena, cebada y/o centeno" en {trigo, avena, cebada, centeno}.
  Iterable<String> _partirEnumeracion(String texto) {
    return texto
        .split(RegExp(r'\s*(?:,|;|/|\by/o\b|\bo\b|\by\b)\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
  }

  DeclaracionAlergenos analizar(String textoCrudo) {
    if (textoCrudo.trim().isEmpty) return DeclaracionAlergenos.vacia;

    final contiene = <String>{};
    final puede = <String>{};
    final lineasContiene = <String>[];
    final lineasPuede = <String>[];
    final noMapeados = <String>[];

    // El bloque "CONTIENE" suele venir en su propia linea, pero a veces sigue en
    // la misma linea que el final de la lista de ingredientes. Se parte por
    // saltos de linea y tambien antes de cada palabra clave.
    final crudoConCortes = textoCrudo
        .replaceAll(RegExp(r'(?=contiene)', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'(?=puede contener)', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'(?=elaborado en)', caseSensitive: false), '\n');

    final lineas = crudoConCortes
        .split('\n')
        .map((l) => _normalizador.normalizarTexto(l))
        .where((l) => l.isNotEmpty);

    for (final linea in lineas) {
      if (_noContiene.hasMatch(linea)) continue;

      final mPuede = _inicioPuede.firstMatch(linea);
      if (mPuede != null) {
        final cola = linea.substring(mPuede.end);
        lineasPuede.add(linea);
        _mapearTokens(cola, puede, noMapeados);
        continue;
      }

      final mContiene = _inicioContiene.firstMatch(linea);
      if (mContiene != null) {
        final cola = linea.substring(mContiene.end);
        lineasContiene.add(linea);
        _mapearTokens(cola, contiene, noMapeados);
        continue;
      }
    }

    return DeclaracionAlergenos(
      contiene: contiene,
      puedeContener: puede,
      lineasContiene: lineasContiene,
      lineasPuedeContener: lineasPuede,
      tokensNoMapeados: noMapeados,
    );
  }

  void _mapearTokens(
    String cola,
    Set<String> destino,
    List<String> noMapeados,
  ) {
    for (final tokenCrudo in _partirEnumeracion(cola)) {
      final token = tokenCrudo.replaceAll(
        RegExp(r'^[\s.,;:*·-]+|[\s.,;:*·-]+$'),
        '',
      );
      final n = _normalizador.normalizarTexto(token);
      if (n.isEmpty) continue;
      final grupoId =
          _tokenAGrupo[n] ??
          _tokenAGrupo[n.replaceFirst(
            RegExp(r'^(?:de|del|la|el|los|las)\s+'),
            '',
          )];
      if (grupoId != null) {
        destino.add(grupoId);
      } else if (n.length > 2) {
        noMapeados.add(token.trim());
      }
    }
  }
}
