import 'package:flutter/foundation.dart';

import 'cliente_claude.dart';
import 'cliente_gemini.dart';

/// Lo que necesitan las funciones de IA de la app (sugerencias de reemplazo,
/// sección 5.6, y "Más info", sección 5.7): mandar un texto con instrucciones
/// y recibir un JSON con un esquema dado. Solo viaja texto (regla 1.2).
///
/// [esquema] va en el formato de Gemini (tipos en mayúsculas, subconjunto de
/// OpenAPI); cada proveedor lo traduce si hace falta.
abstract class GeneradorIA {
  Future<Map<String, dynamic>> generarJson({
    required String sistema,
    required String mensaje,
    required Map<String, dynamic> esquema,
  });

  /// Arma el generador según las claves inyectadas en la compilación: primero
  /// Claude y, si falla, Gemini. Si hay una sola clave, usa solo ese
  /// proveedor; sin ninguna, devuelve `null` (la función queda "sin
  /// configurar").
  static GeneradorIA? desdeConfiguracion(
    Exception Function(String motivo) crearError,
  ) {
    const claveClaude = ClienteClaude.apiKeyDeCompilacion;
    const claveGemini = ClienteGemini.apiKeyDeCompilacion;
    final claude = claveClaude.isEmpty
        ? null
        : ClienteClaude(apiKey: claveClaude, crearError: crearError);
    final gemini = claveGemini.isEmpty
        ? null
        : ClienteGemini(apiKey: claveGemini, crearError: crearError);
    if (claude != null && gemini != null) {
      return GeneradorConRespaldo(principal: claude, respaldo: gemini);
    }
    return claude ?? gemini;
  }
}

/// Usa [principal] y, si falla por cualquier motivo (error, límite de uso,
/// demora, rechazo), [respaldo]. Si fallan los dos, se propaga el error del
/// respaldo.
class GeneradorConRespaldo implements GeneradorIA {
  const GeneradorConRespaldo({required this.principal, required this.respaldo});

  final GeneradorIA principal;
  final GeneradorIA respaldo;

  @override
  Future<Map<String, dynamic>> generarJson({
    required String sistema,
    required String mensaje,
    required Map<String, dynamic> esquema,
  }) async {
    try {
      return await principal.generarJson(
        sistema: sistema,
        mensaje: mensaje,
        esquema: esquema,
      );
    } on Exception catch (e) {
      debugPrint('IA: falló el proveedor principal ($e); se usa el respaldo');
      return respaldo.generarJson(
        sistema: sistema,
        mensaje: mensaje,
        esquema: esquema,
      );
    }
  }
}
