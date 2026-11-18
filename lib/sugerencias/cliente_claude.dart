import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'generador_ia.dart';

/// Conexión con Claude (API de Anthropic) por HTTP directo: no hay SDK oficial
/// de Anthropic para Dart. Es el proveedor principal de las funciones de IA;
/// si falla, [GeneradorConRespaldo] pasa a Gemini.
///
/// Usa salida JSON con esquema (`output_config.format`) y esfuerzo bajo: las
/// tareas son cortas y el usuario está esperando en el supermercado.
class ClienteClaude implements GeneradorIA {
  ClienteClaude({
    required this.apiKey,
    required this.crearError,
    this.modelo = modeloDeCompilacion,
    http.Client? cliente,
    this.timeout = const Duration(seconds: 8),
  }) : _cliente = cliente ?? http.Client();

  /// Se inyecta en la compilación (`ANTHROPIC_API_KEY` en gemini.env, que
  /// dev.ps1 y VS Code pasan con --dart-define-from-file). Nunca se commitea.
  static const apiKeyDeCompilacion = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
  );

  /// Haiku 5.5: el más rápido y barato. Se cambia sin tocar código con
  /// `CLAUDE_MODEL=...` en gemini.env.
  static const modeloDeCompilacion = String.fromEnvironment(
    'CLAUDE_MODEL',
    defaultValue: 'claude-haiku-5-5',
  );

  static final _url = Uri.parse('https://api.anthropic.com/v1/messages');
  static const versionApi = '2026-10-21';

  final String apiKey;
  final String modelo;
  final Exception Function(String motivo) crearError;
  final http.Client _cliente;

  /// Pasado este tiempo se abandona Claude y se prueba Gemini: así la espera
  /// total del usuario queda acotada.
  final Duration timeout;

  @visibleForTesting
  static Map<String, String> construirHeaders(String apiKey) => {
    'content-type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': versionApi,
  };

  @visibleForTesting
  static Map<String, dynamic> construirCuerpo({
    required String modelo,
    required String sistema,
    required String mensaje,
    required Map<String, dynamic> esquema,
  }) => {
    'model': modelo,
    // Holgado: incluye el razonamiento del modelo; cortar a mitad de un JSON
    // lo haría inválido.
    'max_tokens': 4096,
    'system': sistema,
    'messages': [
      {'role': 'user', 'content': mensaje},
    ],
    'output_config': {
      'effort': 'low',
      'format': {'type': 'json_schema', 'schema': esquemaJson(esquema)},
    },
  };

  /// Traduce el esquema de Gemini (tipos en mayúsculas) a JSON Schema como lo
  /// pide Claude: tipos en minúsculas y `additionalProperties: false` en cada
  /// objeto.
  @visibleForTesting
  static Map<String, dynamic> esquemaJson(Map<String, dynamic> gemini) {
    final resultado = <String, dynamic>{};
    for (final e in gemini.entries) {
      switch (e.key) {
        case 'type':
          resultado['type'] = (e.value as String).toLowerCase();
        case 'properties':
          resultado['properties'] = {
            for (final p in (e.value as Map<String, dynamic>).entries)
              p.key: esquemaJson(p.value as Map<String, dynamic>),
          };
        case 'items':
          resultado['items'] = esquemaJson(e.value as Map<String, dynamic>);
        default:
          resultado[e.key] = e.value;
      }
    }
    if (resultado['type'] == 'object') {
      resultado['additionalProperties'] = false;
    }
    return resultado;
  }

  /// Extrae el JSON de la respuesta. Un rechazo o una respuesta cortada son
  /// errores: con [GeneradorConRespaldo] se pasa a Gemini.
  @visibleForTesting
  static Map<String, dynamic> extraerJson(
    Map<String, dynamic> json,
    Exception Function(String) crearError,
  ) {
    final fin = json['stop_reason'] as String?;
    if (fin == 'refusal') throw crearError('el modelo rechazó el pedido');
    if (fin == 'max_tokens') throw crearError('respuesta incompleta');
    final texto = [
      for (final b in json['content'] as List<dynamic>? ?? const [])
        if (b is Map && b['type'] == 'text' && b['text'] is String)
          b['text'] as String,
    ].join();
    if (texto.trim().isEmpty) throw crearError('respuesta vacía');
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> generarJson({
    required String sistema,
    required String mensaje,
    required Map<String, dynamic> esquema,
  }) async {
    final cuerpo = jsonEncode(
      construirCuerpo(
        modelo: modelo,
        sistema: sistema,
        mensaje: mensaje,
        esquema: esquema,
      ),
    );
    debugPrint('Claude: consultando $modelo');
    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(_url, headers: construirHeaders(apiKey), body: cuerpo)
          .timeout(timeout);
    } on TimeoutException {
      debugPrint('Claude: tiempo de espera agotado');
      throw crearError('tiempo de espera agotado');
    } catch (e) {
      debugPrint('Claude: error de conexión');
      throw crearError('sin conexión: $e');
    }
    if (respuesta.statusCode != 200) {
      // El cuerpo del error no incluye la clave.
      debugPrint(
        'Claude HTTP ${respuesta.statusCode}: '
        '${utf8.decode(respuesta.bodyBytes)}',
      );
      throw crearError(
        respuesta.statusCode == 429
            ? 'límite de uso alcanzado'
            : 'HTTP ${respuesta.statusCode}',
      );
    }
    debugPrint('Claude: respuesta válida de $modelo');
    final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
    return extraerJson(json as Map<String, dynamic>, crearError);
  }
}
