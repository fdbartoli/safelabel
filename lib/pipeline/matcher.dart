import '../datos/base_conocimiento.dart';
import '../modelo/ingrediente.dart';
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
    required this.ingrediente,
    required this.exacta,
    required this.similitud,
    required this.terminoBase,
  });

  final Ingrediente ingrediente;

  /// `true` si fue match exacto; `false` si fue difuso.
  final bool exacta;

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
  const Emparejador(
    this.base, {
    this.umbralDifuso = 0.84,
    this.umbralSospechaOcr = 0.62,
  });

  final BaseConocimiento base;

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
    final exacto = base.matchExacto(texto);
    if (exacto != null) {
      return Coincidencia(
        item,
        ingrediente: exacto,
        exacta: true,
        similitud: 1,
        terminoBase: base.etiquetaDe(texto),
      );
    }

    // 2. Difuso: mejor término de la base.
    var mejor = 0.0;
    String? mejorTermino;
    for (final termino in base.terminosIndexados) {
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
        ingrediente: base.matchExacto(mejorTermino)!,
        exacta: false,
        similitud: mejor,
        terminoBase: base.etiquetaDe(mejorTermino),
      );
    }

    // 3. Desconocido. La similitud decide si parece typo de OCR o término nuevo.
    return SinCoincidencia(
      item,
      mejorSimilitud: mejor,
      candidato: mejor >= umbralSospechaOcr && mejorTermino != null
          ? base.etiquetaDe(mejorTermino)
          : null,
      probableErrorOcr: mejor >= umbralSospechaOcr,
    );
  }

  List<ResultadoMatch> matchTodos(Iterable<ItemNormalizado> items) => [
    for (final i in items) match(i),
  ];
}
