import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'linea_ocr.dart';
import 'servicio_ocr.dart';

/// OCR en el dispositivo con ML Kit (Android) / Apple Vision (iOS).
///
/// La confianza por línea solo es fiable en Apple Vision; en ML Kit para Android
/// suele venir nula. Cuando falta, se asume alta y el triage se apoya en la
/// similitud difusa del matcher para detectar lecturas dudosas (sección 5.1).
class ServicioOcrMlKit implements ServicioOcr {
  ServicioOcrMlKit()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<LecturaOcr> reconocer(String rutaImagen) async {
    final entrada = InputImage.fromFilePath(rutaImagen);
    final resultado = await _recognizer.processImage(entrada);

    final lineas = <LineaOcr>[];
    var indice = 0;
    for (final bloque in resultado.blocks) {
      for (final linea in bloque.lines) {
        lineas.add(
          LineaOcr(
            texto: linea.text,
            confianza: _confianzaDe(linea),
            indice: indice++,
          ),
        );
      }
    }
    return LecturaOcr(lineas);
  }

  double _confianzaDe(TextLine linea) {
    final propia = linea.confidence;
    if (propia != null) return propia.clamp(0.0, 1.0);

    // Sin confianza nativa: promedio de la de los elementos, si hay.
    final valores = [
      for (final e in linea.elements)
        if (e.confidence != null) e.confidence!.clamp(0.0, 1.0),
    ];
    if (valores.isEmpty) return 1.0;
    return valores.reduce((a, b) => a + b) / valores.length;
  }

  @override
  Future<void> liberar() => _recognizer.close();
}
