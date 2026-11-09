import '../conocimiento/catalogo_conocimiento.dart';
import '../datos/base_conocimiento.dart';
import 'normalizador.dart';
import 'similitud.dart';

/// Paso 5 del Flujo B: match de cada ítem normalizado contra la base local,
/// en el orden exacto → difuso → desconocido (sección 5.1).
///
/// Los tres estados nunca se colapsan:
///  - [Coincidencia]        → MATCHED
///  - [SinCoincidencia] con [SinCoincidencia.probableErrorOcr] `true`  → tratar
///    como no legible: otra foto puede resolverlo
///  - [SinCoincidencia] con [SinCoincidencia.probableErrorOcr] `false` → UNKNOWN
///    real: otra foto no cambia nada, va a la cola de desconocidos
sealed class ResultadoMatch {
  const ResultadoMatch(this.item);
  final ItemNormalizado item;
}

class Coincidencia extends ResultadoMatch {
  const Coincidencia(
    super.item, {
    required this.concepto,
    required this.exacta,
    required this.similitud,
    required this.terminoBase,
    this.porContencion = false,
  });

  final ConceptoConocimiento concepto;

  /// `true` si fue match exacto; `false` si fue difuso o por contención.
  final bool exacta;

  /// `true` si el ítem no es el término, sino que lo contiene como palabras:
  /// "harina de trigo tipo 000 enriquecida" contiene "harina de trigo".
  final bool porContencion;

  /// 1.0 en match exacto; en (0, 1) para el difuso.
  final double similitud;

  /// Término de la base (nombre o sinónimo) con el que coincidió.
  final String terminoBase;
}

class SinCoincidencia extends ResultadoMatch {
  const SinCoincidencia(
    super.item, {
    required this.mejorSimilitud,
    required this.candidato,
    required this.probableErrorOcr,
  });

  /// Mejor similitud encontrada contra la base (aunque no alcance el umbral).
  final double mejorSimilitud;

  /// Término de la base más parecido, si hay alguno razonablemente cercano.
  final String? candidato;

  /// `true` → se parece bastante a algo conocido: probablemente error de OCR.
  /// `false` → no se parece a nada: término desconocido genuino.
  final bool probableErrorOcr;
}

class Emparejador {
  Emparejador(
    BaseConocimiento base, {
    this.umbralDifuso = 0.84,
    this.umbralSospechaOcr = 0.62,
  }) : catalogo = CatalogoConocimiento.desdeBaseLegacy(base);

  // No es `const`: la lista de términos para contención se arma una vez, en
  // forma diferida.
  Emparejador.desdeCatalogo(
    this.catalogo, {
    this.umbralDifuso = 0.84,
    this.umbralSospechaOcr = 0.62,
  });

  final CatalogoConocimiento catalogo;

  /// Términos de la base cuyo concepto está relacionado con alguna
  /// restricción, con su patrón de palabra completa (plural tolerado), del más
  /// largo al más corto. Para la búsqueda por contención.
  late final List<(String, Set<String>, RegExp)> _terminosConAlergeno = () {
    final lista = <(String, Set<String>, RegExp)>[];
    for (final t in catalogo.terminosIndexados) {
      final relaciones = catalogo.matchExacto(t)?.relaciones ?? const [];
      // Mínimo 4 letras: "soja", "mani", "nuez" entran; "sal" o "soy" no.
      if (relaciones.isEmpty || t.replaceAll(' ', '').length < 4) continue;
      lista.add((
        t,
        {for (final r in relaciones) r.perfilId},
        RegExp('(?:^| )${RegExp.escape(t)}(?:s|es)?(?: |\$)'),
      ));
    }
    lista.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return lista;
  }();

  /// A partir de esta similitud se acepta como coincidencia difusa.
  final double umbralDifuso;

  /// Entre [umbralSospechaOcr] y [umbralDifuso]: no se afirma la coincidencia,
  /// pero se marca como probable error de OCR.
  final double umbralSospechaOcr;

  ResultadoMatch match(ItemNormalizado item) {
    final texto = item.textoNormalizado;
    if (texto.isEmpty) {
      return SinCoincidencia(
        item,
        mejorSimilitud: 0,
        candidato: null,
        probableErrorOcr: false,
      );
    }

    // 1. Exacto.
    final exacto = catalogo.matchExacto(texto);
    if (exacto != null) {
      return Coincidencia(
        item,
        concepto: exacto,
        exacta: true,
        similitud: 1,
        terminoBase: catalogo.etiquetaDe(texto),
      );
    }

    // 2. Contención de un término con alérgeno: va antes que el difuso para
    //    que "aceite de mani" no termine emparejado con "aceite de maiz".
    final contenidos = _contenidosConAlergeno(item);
    if (contenidos.isNotEmpty) return contenidos.first;

    // 3. Difuso: mejor término de la base.
    var mejor = 0.0;
    String? mejorTermino;
    for (final termino in catalogo.terminosIndexados) {
      final s = similitud(texto, termino);
      if (s > mejor) {
        mejor = s;
        mejorTermino = termino;
        if (mejor == 1) break;
      }
    }

    if (mejor >= umbralDifuso && mejorTermino != null) {
      return Coincidencia(
        item,
        concepto: catalogo.matchExacto(mejorTermino)!,
        exacta: false,
        similitud: mejor,
        terminoBase: catalogo.etiquetaDe(mejorTermino),
      );
    }

    // 4. Desconocido. La similitud decide si parece typo de OCR o término nuevo.
    return SinCoincidencia(
      item,
      mejorSimilitud: mejor,
      candidato: mejor >= umbralSospechaOcr && mejorTermino != null
          ? catalogo.etiquetaDe(mejorTermino)
          : null,
      probableErrorOcr: mejor >= umbralSospechaOcr,
    );
  }

  /// Coincidencias por los términos con restricción contenidos en el ítem:
  /// el término más largo primero, y uno más solo si suma una restricción que
  /// los anteriores no cubrían. Vacío si no contiene ninguno.
  List<Coincidencia> _contenidosConAlergeno(ItemNormalizado item) {
    final texto = item.textoNormalizado;
    final cubiertas = <String>{};
    final resultado = <Coincidencia>[];
    for (final (termino, restricciones, patron) in _terminosConAlergeno) {
      if (cubiertas.containsAll(restricciones)) continue;
      if (!patron.hasMatch(texto)) continue;
      cubiertas.addAll(restricciones);
      resultado.add(
        Coincidencia(
          item,
          concepto: catalogo.matchExacto(termino)!,
          exacta: false,
          similitud: 1,
          terminoBase: catalogo.etiquetaDe(termino),
          porContencion: true,
        ),
      );
    }
    return resultado;
  }

  /// Todas las coincidencias de cada ítem. Un ítem que contiene términos de
  /// más de un grupo ("galletita de trigo con leche") genera una por grupo,
  /// para que ningún perfil se pierda el suyo.
  ///
  /// Un match exacto manda: "manteca de cacao" es cacao (sin alérgeno), no
  /// "manteca" (leche), aunque contenga la palabra.
  List<ResultadoMatch> matchTodos(Iterable<ItemNormalizado> items) => [
    for (final i in items) ...() {
      final principal = match(i);
      if (principal is Coincidencia && principal.porContencion) {
        return _contenidosConAlergeno(i);
      }
      return [principal];
    }(),
  ];
}
