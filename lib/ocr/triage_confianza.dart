import 'linea_ocr.dart';

/// Paso 3 del Flujo B: triage de confianza.
///
/// Regla 1.5: toda lectura parcial se declara. Las líneas por debajo del umbral
/// no se descartan en silencio: se informan como no legibles, indicando cuál
/// falló, para pedir una nueva foto de esa parte.
class ResultadoTriage {
  const ResultadoTriage({required this.legibles, required this.noLegibles});

  /// Líneas con confianza suficiente para analizar.
  final List<LineaOcr> legibles;

  /// Líneas que el OCR no leyó con seguridad. Otra foto puede resolverlas.
  final List<LineaOcr> noLegibles;

  bool get hayLecturaParcial => noLegibles.isNotEmpty;

  /// Texto de las líneas legibles, para pasar al normalizador.
  String get textoLegible => legibles.map((l) => l.texto).join('\n');
}

class TriageConfianza {
  const TriageConfianza({this.umbral = 0.6});

  /// Debajo de esta confianza la línea se considera no legible.
  final double umbral;

  ResultadoTriage clasificar(LecturaOcr lectura) {
    final legibles = <LineaOcr>[];
    final noLegibles = <LineaOcr>[];
    for (final linea in lectura.lineas) {
      if (linea.texto.trim().isEmpty) continue;
      if (linea.confianza >= umbral) {
        legibles.add(linea);
      } else {
        noLegibles.add(linea);
      }
    }
    return ResultadoTriage(legibles: legibles, noLegibles: noLegibles);
  }
}
