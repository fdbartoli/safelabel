import 'linea_ocr.dart';

/// Contrato del OCR en el dispositivo (paso 2 del Flujo B).
///
/// Regla 1.2: la imagen no sale del dispositivo ni llega a un LLM. La
/// implementación real usa ML Kit / Apple Vision; los tests usan un doble.
abstract class ServicioOcr {
  /// Reconoce el texto de la imagen en [rutaImagen] y devuelve las líneas con
  /// su confianza.
  Future<LecturaOcr> reconocer(String rutaImagen);

  /// Libera recursos nativos.
  Future<void> liberar();
}

/// Doble de OCR para desarrollo y tests: recibe el texto ya resuelto.
class ServicioOcrFalso implements ServicioOcr {
  ServicioOcrFalso(this.lecturaFija);

  final LecturaOcr lecturaFija;

  @override
  Future<LecturaOcr> reconocer(String rutaImagen) async => lecturaFija;

  @override
  Future<void> liberar() async {}

  /// Construye una lectura a partir de texto plano, una línea por salto de
  /// línea, con confianza uniforme.
  factory ServicioOcrFalso.desdeTexto(String texto, {double confianza = 0.95}) {
    final lineas = <LineaOcr>[];
    var i = 0;
    for (final l in texto.split('\n')) {
      lineas.add(LineaOcr(texto: l, confianza: confianza, indice: i++));
    }
    return ServicioOcrFalso(LecturaOcr(lineas));
  }
}
