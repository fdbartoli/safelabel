import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sugerencias de reemplazo por LLM (CLAUDE.md, sección 5.6).
///
/// Excepción explícita a las reglas 1.1 y 1.4: el LLM propone categorías de
/// alimentos, pero nunca decide si son aptas. El filtro determinista de
/// [FiltroReemplazos] descarta cualquier sugerencia que choque con un perfil
/// activo antes de mostrarla.
class SolicitudReemplazo {
  const SolicitudReemplazo({
    required this.gruposRestringidos,
    required this.ingredientesConflictivos,
    required this.ingredientesLeidos,
  });

  /// Nombres de los grupos de alérgenos que restringen los perfiles activos
  /// ("leche", "cereales con gluten").
  final List<String> gruposRestringidos;

  /// Los ingredientes de la etiqueta que chocaron con algún perfil.
  final List<String> ingredientesConflictivos;

  /// Lista completa leída, para que el LLM entienda qué tipo de producto es.
  final List<String> ingredientesLeidos;
}

class SugerenciaReemplazo {
  const SugerenciaReemplazo({required this.nombre, required this.motivo});

  /// Categoría genérica, no marca ("bebida de avena").
  final String nombre;

  /// Por qué el LLM la propone. Texto del LLM, no verificado.
  final String motivo;
}

class RespuestaReemplazos {
  const RespuestaReemplazos({
    required this.tipoProducto,
    required this.sugerencias,
  });

  final String tipoProducto;
  final List<SugerenciaReemplazo> sugerencias;

  static const vacia = RespuestaReemplazos(tipoProducto: '', sugerencias: []);
}

/// Error controlado: se avisa en la pantalla y se puede reintentar; los tres
/// bloques del resultado no cambian.
class ErrorReemplazos implements Exception {
  const ErrorReemplazos(this.motivo);
  final String motivo;

  @override
  String toString() => 'ErrorReemplazos: $motivo';
}

abstract class ServicioReemplazos {
  Future<RespuestaReemplazos> sugerir(SolicitudReemplazo solicitud);
}

/// Llama a la API de Google Gemini (plan gratuito) por HTTP directo, con el
/// método `generateContent` y salida JSON con esquema.
class ServicioReemplazosGemini implements ServicioReemplazos {
  ServicioReemplazosGemini({
    required this.apiKey,
    this.modelo = modeloDeCompilacion,
    http.Client? cliente,
    this.timeout = const Duration(seconds: 45),
  }) : _cliente = cliente ?? http.Client();

  /// Se inyecta en la compilación con `--dart-define=GEMINI_API_KEY=...`
  /// (lo hace dev.ps1 desde la variable de entorno). Nunca se commitea.
  static const apiKeyDeCompilacion = String.fromEnvironment('GEMINI_API_KEY');

  /// Modelo del plan gratuito. Se puede cambiar sin tocar código con
  /// `--dart-define=GEMINI_MODEL=...`.
  static const modeloDeCompilacion =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.8-flash');

  final String apiKey;
  final String modelo;
  final http.Client _cliente;
  final Duration timeout;

  Uri get _url => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent');

  static const _system =
      'Sos un asistente que sugiere alimentos sustitutos para una app '
      'argentina de lectura de etiquetas. La persona escaneó un producto que '
      'contiene ingredientes que chocan con sus restricciones alimentarias.\n'
      '\n'
      'Reglas:\n'
      '- Sugerí entre 3 y 5 categorías genéricas de alimentos que cumplan la '
      'misma función que el producto escaneado. Nunca nombres marcas.\n'
      '- Ninguna sugerencia puede contener, por definición, alguno de los '
      'grupos restringidos. No uses en el nombre palabras de los grupos '
      'restringidos (por ejemplo, si la leche está restringida, decí "bebida '
      'de avena", no "leche de avena").\n'
      '- Preferí alimentos fáciles de conseguir en un supermercado argentino.\n'
      '- Nunca afirmes que algo es apto o seguro: la persona siempre va a '
      'revisar la etiqueta del sustituto.\n'
      '- Escribí en español rioplatense, con frases cortas.';

  /// Esquema en el formato de `responseSchema` de Gemini (subconjunto de
  /// OpenAPI, tipos en mayúsculas).
  static const _esquema = {
    'type': 'OBJECT',
    'properties': {
      'tipo_producto': {
        'type': 'STRING',
        'description': 'Qué tipo de producto parece ser, en pocas palabras.',
      },
      'sugerencias': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'nombre': {'type': 'STRING'},
            'motivo': {'type': 'STRING'},
          },
          'required': ['nombre', 'motivo'],
        },
      },
    },
    'required': ['tipo_producto', 'sugerencias'],
  };

  @visibleForTesting
  static Map<String, dynamic> construirCuerpo(SolicitudReemplazo s) {
    final prompt = StringBuffer()
      ..writeln('Grupos restringidos: ${s.gruposRestringidos.join(', ')}')
      ..writeln(
          'Ingredientes que chocan: ${s.ingredientesConflictivos.join(', ')}')
      ..writeln('Lista completa de ingredientes: '
          '${s.ingredientesLeidos.join(', ')}');
    return {
      'systemInstruction': {
        'parts': [
          {'text': _system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt.toString()},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _esquema,
      },
    };
  }

  @visibleForTesting
  static Map<String, String> construirHeaders(String apiKey) => {
        'content-type': 'application/json',
        'x-goog-api-key': apiKey,
      };

  @visibleForTesting
  static RespuestaReemplazos parsearRespuesta(Map<String, dynamic> json) {
    final bloqueo = (json['promptFeedback'] as Map?)?['blockReason'];
    if (bloqueo != null) {
      throw ErrorReemplazos('pedido bloqueado por el modelo: $bloqueo');
    }
    final candidatos = json['candidates'] as List<dynamic>? ?? const [];
    if (candidatos.isEmpty) {
      throw const ErrorReemplazos('el modelo no devolvió respuesta');
    }
    final candidato = candidatos.first as Map<String, dynamic>;
    final fin = candidato['finishReason'] as String?;
    if (fin == 'MAX_TOKENS') {
      throw const ErrorReemplazos('respuesta incompleta');
    }
    if (fin != null && fin != 'STOP') {
      throw ErrorReemplazos('el modelo cortó la respuesta: $fin');
    }
    final partes =
        (candidato['content'] as Map?)?['parts'] as List<dynamic>? ?? const [];
    final texto = [
      for (final p in partes)
        // Las partes con `thought: true` son razonamiento, no la respuesta.
        if (p is Map && p['thought'] != true && p['text'] is String)
          p['text'] as String,
    ].join();
    if (texto.trim().isEmpty) {
      throw const ErrorReemplazos('respuesta vacía');
    }
    final datos = jsonDecode(texto) as Map<String, dynamic>;
    return RespuestaReemplazos(
      tipoProducto: datos['tipo_producto'] as String? ?? '',
      sugerencias: [
        for (final s in (datos['sugerencias'] as List<dynamic>? ?? const []))
          SugerenciaReemplazo(
            nombre: (s['nombre'] as String).trim(),
            motivo: (s['motivo'] as String? ?? '').trim(),
          ),
      ],
    );
  }

  @override
  Future<RespuestaReemplazos> sugerir(SolicitudReemplazo solicitud) async {
    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(
            _url,
            headers: construirHeaders(apiKey),
            body: jsonEncode(construirCuerpo(solicitud)),
          )
          .timeout(timeout);
    } catch (e) {
      throw ErrorReemplazos('sin conexión: $e');
    }
    if (respuesta.statusCode == 429) {
      throw const ErrorReemplazos('límite del plan gratuito alcanzado');
    }
    if (respuesta.statusCode != 200) {
      debugPrint('Gemini HTTP ${respuesta.statusCode}: ${respuesta.body}');
      throw ErrorReemplazos('HTTP ${respuesta.statusCode}');
    }
    final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
    return parsearRespuesta(json as Map<String, dynamic>);
  }
}
