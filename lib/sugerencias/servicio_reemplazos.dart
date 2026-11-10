import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cliente_gemini.dart';

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

/// Llama a la API de Google Gemini (plan gratuito) con [ClienteGemini], que
/// maneja los modelos de respaldo y los errores.
class ServicioReemplazosGemini implements ServicioReemplazos {
  ServicioReemplazosGemini({
    required String apiKey,
    String modelo = modeloDeCompilacion,
    http.Client? cliente,
    Duration timeoutPorModelo = const Duration(seconds: 8),
    Duration timeoutTotal = const Duration(seconds: 20),
  }) : _gemini = ClienteGemini(
         apiKey: apiKey,
         modelo: modelo,
         cliente: cliente,
         timeoutPorModelo: timeoutPorModelo,
         timeoutTotal: timeoutTotal,
         crearError: ErrorReemplazos.new,
       );

  static const apiKeyDeCompilacion = ClienteGemini.apiKeyDeCompilacion;
  static const modeloDeCompilacion = ClienteGemini.modeloDeCompilacion;
  static const modelos = ClienteGemini.modelos;

  final ClienteGemini _gemini;

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
        'Ingredientes que chocan: ${s.ingredientesConflictivos.join(', ')}',
      )
      ..writeln(
        'Lista completa de ingredientes: '
        '${s.ingredientesLeidos.join(', ')}',
      );
    return ClienteGemini.construirCuerpo(
      sistema: _system,
      mensaje: prompt.toString(),
      esquema: _esquema,
    );
  }

  @visibleForTesting
  static Map<String, String> construirHeaders(String apiKey) =>
      ClienteGemini.construirHeaders(apiKey);

  @visibleForTesting
  static RespuestaReemplazos parsearRespuesta(Map<String, dynamic> json) =>
      _desdeDatos(ClienteGemini.extraerJson(json, ErrorReemplazos.new));

  static RespuestaReemplazos _desdeDatos(Map<String, dynamic> datos) =>
      RespuestaReemplazos(
        tipoProducto: datos['tipo_producto'] as String? ?? '',
        sugerencias: [
          for (final s in (datos['sugerencias'] as List<dynamic>? ?? const []))
            SugerenciaReemplazo(
              nombre: (s['nombre'] as String).trim(),
              motivo: (s['motivo'] as String? ?? '').trim(),
            ),
        ],
      );

  @override
  Future<RespuestaReemplazos> sugerir(SolicitudReemplazo solicitud) async =>
      _desdeDatos(await _gemini.generar(construirCuerpo(solicitud)));
}
