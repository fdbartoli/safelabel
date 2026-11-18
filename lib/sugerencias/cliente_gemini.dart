import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Conexión con Google Gemini (plan gratuito) por HTTP directo, compartida por
/// las funciones de IA de la app: sugerencias de reemplazo (sección 5.6) y
/// "Más info" de un ingrediente (sección 5.7). Solo viaja texto (regla 1.2).
///
/// Prueba los modelos en orden y pasa al siguiente solo ante HTTP 503 o
/// timeout. Los errores se lanzan con [crearError], para que cada función
/// tenga su propio tipo de error.
class ClienteGemini {
  ClienteGemini({
    required this.apiKey,
    required this.crearError,
    this.modelo = modeloDeCompilacion,
    http.Client? cliente,
    this.timeoutPorModelo = const Duration(seconds: 8),
    this.timeoutTotal = const Duration(seconds: 20),
  }) : _cliente = cliente ?? http.Client();

  /// Se inyecta en la compilación con `--dart-define=GEMINI_API_KEY=...`
  /// (lo hace dev.ps1). Nunca se commitea.
  static const apiKeyDeCompilacion = String.fromEnvironment('GEMINI_API_KEY');

  /// Modelo principal. Se puede cambiar con `--dart-define=GEMINI_MODEL=...`;
  /// si se define, se intenta primero y no se repite en la cadena.
  static const modeloDeCompilacion = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.1-flash-lite',
  );

  /// Orden de preferencia de los modelos.
  static const modelos = [
    'gemini-3.1-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
  ];

  final String apiKey;
  final String modelo;
  final Exception Function(String motivo) crearError;
  final http.Client _cliente;
  final Duration timeoutPorModelo;
  final Duration timeoutTotal;

  List<String> get cadena {
    final principal = modelo.trim();
    if (principal.isEmpty) return modelos;
    return [principal, ...modelos.where((m) => m != principal)];
  }

  Uri _url(String modelo) => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent',
  );

  static Map<String, String> construirHeaders(String apiKey) => {
    'content-type': 'application/json',
    'x-goog-api-key': apiKey,
  };

  /// Cuerpo de `generateContent` con instrucción de sistema, un mensaje de
  /// usuario y salida JSON con [esquema].
  static Map<String, dynamic> construirCuerpo({
    required String sistema,
    required String mensaje,
    required Map<String, dynamic> esquema,
  }) => {
    'systemInstruction': {
      'parts': [
        {'text': sistema},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': mensaje},
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': esquema,
    },
  };

  /// Extrae el JSON de la respuesta de Gemini, ignorando las partes de
  /// razonamiento (`thought: true`). Lanza con [crearError] si el modelo
  /// bloqueó o cortó la respuesta.
  static Map<String, dynamic> extraerJson(
    Map<String, dynamic> json,
    Exception Function(String) crearError,
  ) {
    final bloqueo = (json['promptFeedback'] as Map?)?['blockReason'];
    if (bloqueo != null) {
      throw crearError('pedido bloqueado por el modelo: $bloqueo');
    }
    final candidatos = json['candidates'] as List<dynamic>? ?? const [];
    if (candidatos.isEmpty) {
      throw crearError('el modelo no devolvió respuesta');
    }
    final candidato = candidatos.first as Map<String, dynamic>;
    final fin = candidato['finishReason'] as String?;
    if (fin == 'MAX_TOKENS') throw crearError('respuesta incompleta');
    if (fin != null && fin != 'STOP') {
      throw crearError('el modelo cortó la respuesta: $fin');
    }
    final partes =
        (candidato['content'] as Map?)?['parts'] as List<dynamic>? ?? const [];
    final texto = [
      for (final p in partes)
        if (p is Map && p['thought'] != true && p['text'] is String)
          p['text'] as String,
    ].join();
    if (texto.trim().isEmpty) throw crearError('respuesta vacía');
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  /// Envía [cuerpo] y devuelve el JSON generado por el modelo.
  Future<Map<String, dynamic>> generar(Map<String, dynamic> cuerpo) async {
    final cuerpoTexto = jsonEncode(cuerpo);
    final reloj = Stopwatch()..start();
    final cadena = this.cadena;
    Exception? ultimoError;

    for (var i = 0; i < cadena.length; i++) {
      final modelo = cadena[i];
      final restante = timeoutTotal - reloj.elapsed;
      if (restante <= Duration.zero) {
        debugPrint('Gemini: tiempo total de espera agotado');
        throw crearError('tiempo de espera agotado');
      }
      final espera = restante < timeoutPorModelo ? restante : timeoutPorModelo;
      debugPrint(
        'Gemini: intentando modelo $modelo (${i + 1}/${cadena.length})',
      );

      final http.Response respuesta;
      try {
        respuesta = await _cliente
            .post(
              _url(modelo),
              headers: construirHeaders(apiKey),
              body: cuerpoTexto,
            )
            .timeout(espera);
      } on TimeoutException {
        ultimoError = crearError('tiempo de espera agotado');
        debugPrint('Gemini: timeout en modelo $modelo');
        continue;
      } catch (e) {
        // Un error de conexión no es un 503: no se prueba otro modelo.
        debugPrint('Gemini: error de conexión en modelo $modelo');
        throw crearError('sin conexión: $e');
      }

      if (respuesta.statusCode == 200) {
        debugPrint('Gemini: respuesta válida de modelo $modelo');
        final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
        return extraerJson(json as Map<String, dynamic>, crearError);
      }
      if (respuesta.statusCode == 503) {
        ultimoError = crearError('HTTP 503');
        debugPrint('Gemini: modelo $modelo no disponible (HTTP 503)');
        continue;
      }
      if (respuesta.statusCode == 429) {
        debugPrint(
          'Gemini: límite del plan gratuito en modelo $modelo (HTTP 429)',
        );
        throw crearError('límite del plan gratuito alcanzado');
      }
      debugPrint(
        'Gemini HTTP ${respuesta.statusCode} en modelo $modelo: '
        '${respuesta.body}',
      );
      throw crearError('HTTP ${respuesta.statusCode}');
    }
    throw ultimoError ?? crearError('sin respuesta del modelo');
  }
}
