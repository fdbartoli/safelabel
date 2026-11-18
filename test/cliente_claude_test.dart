import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safelabel/sugerencias/cliente_claude.dart';
import 'package:safelabel/sugerencias/generador_ia.dart';
import 'package:safelabel/sugerencias/info_ingrediente.dart';
import 'package:safelabel/modelo/semaforo.dart';

class _Error implements Exception {
  const _Error(this.motivo);
  final String motivo;
  @override
  String toString() => motivo;
}

/// Generador falso: responde [datos] o falla, y cuenta las llamadas.
class _GeneradorFalso implements GeneradorIA {
  _GeneradorFalso({this.datos, this.error});
  final Map<String, dynamic>? datos;
  final Exception? error;
  int llamadas = 0;

  @override
  Future<Map<String, dynamic>> generarJson({
    required String sistema,
    required String mensaje,
    required Map<String, dynamic> esquema,
  }) async {
    llamadas++;
    if (error != null) throw error!;
    return datos!;
  }
}

http.Response _respuestaClaude(
  Map<String, dynamic> datos, {
  String stop = 'end_turn',
}) => http.Response(
  jsonEncode({
    'model': 'claude-haiku-5-5',
    'stop_reason': stop,
    'content': [
      {'type': 'thinking', 'thinking': ''},
      {'type': 'text', 'text': jsonEncode(datos)},
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _esquemaGemini = {
  'type': 'OBJECT',
  'properties': {
    'que_es': {'type': 'STRING'},
    'items': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'nombre': {'type': 'STRING'},
        },
        'required': ['nombre'],
      },
    },
  },
  'required': ['que_es'],
};

void main() {
  group('pedido a Claude', () {
    test('usa Haiku 5.5 por defecto, esfuerzo bajo y salida JSON', () {
      expect(ClienteClaude.modeloDeCompilacion, 'claude-haiku-5-5');
      final cuerpo = ClienteClaude.construirCuerpo(
        modelo: 'claude-haiku-5-5',
        sistema: 'instrucciones',
        mensaje: 'harina de trigo',
        esquema: _esquemaGemini,
      );
      expect(cuerpo['model'], 'claude-haiku-5-5');
      expect(cuerpo['system'], 'instrucciones');
      expect(cuerpo['output_config']['effort'], 'low');
      expect(cuerpo['output_config']['format']['type'], 'json_schema');
      // Solo texto: nunca una imagen (regla 1.2).
      expect(jsonEncode(cuerpo), isNot(contains('image')));
    });

    test('traduce el esquema de Gemini a JSON Schema', () {
      final s = ClienteClaude.esquemaJson(_esquemaGemini);
      expect(s['type'], 'object');
      expect(s['additionalProperties'], false);
      expect(s['properties']['que_es']['type'], 'string');
      expect(s['properties']['items']['type'], 'array');
      final item = s['properties']['items']['items'];
      expect(item['type'], 'object');
      expect(item['additionalProperties'], false);
      expect(item['required'], ['nombre']);
    });

    test('la clave va en el header, no en la URL ni en el cuerpo', () {
      final h = ClienteClaude.construirHeaders('clave-secreta');
      expect(h['x-api-key'], 'clave-secreta');
      expect(h['anthropic-version'], ClienteClaude.versionApi);
    });
  });

  group('respuesta de Claude', () {
    test('lee el JSON del bloque de texto e ignora el razonamiento', () async {
      final cliente = ClienteClaude(
        apiKey: 'k',
        crearError: _Error.new,
        cliente: MockClient(
          (_) async => _respuestaClaude({'que_es': 'Un cereal molido.'}),
        ),
      );
      final datos = await cliente.generarJson(
        sistema: 's',
        mensaje: 'm',
        esquema: _esquemaGemini,
      );
      expect(datos['que_es'], 'Un cereal molido.');
    });

    test('un rechazo o una respuesta cortada son errores', () {
      for (final stop in ['refusal', 'max_tokens']) {
        expect(
          () => ClienteClaude.extraerJson(
            jsonDecode(_respuestaClaude({}, stop: stop).body),
            _Error.new,
          ),
          throwsA(isA<_Error>()),
          reason: stop,
        );
      }
    });

    test('un error HTTP es un error (y no expone la clave)', () async {
      final cliente = ClienteClaude(
        apiKey: 'clave-secreta',
        crearError: _Error.new,
        cliente: MockClient((_) async => http.Response('{"error":{}}', 529)),
      );
      await expectLater(
        cliente.generarJson(sistema: 's', mensaje: 'm', esquema: {}),
        throwsA(
          isA<_Error>().having(
            (e) => e.motivo,
            'motivo',
            allOf(contains('529'), isNot(contains('clave-secreta'))),
          ),
        ),
      );
    });

    test('si tarda más del límite, se abandona', () async {
      final cliente = ClienteClaude(
        apiKey: 'k',
        crearError: _Error.new,
        timeout: const Duration(milliseconds: 50),
        cliente: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return _respuestaClaude({'que_es': 'tarde'});
        }),
      );
      await expectLater(
        cliente.generarJson(sistema: 's', mensaje: 'm', esquema: {}),
        throwsA(
          isA<_Error>().having((e) => e.motivo, 'motivo', contains('tiempo')),
        ),
      );
    });
  });

  group('Claude primero, Gemini de respaldo', () {
    test('si Claude responde, Gemini no se llama', () async {
      final claude = _GeneradorFalso(datos: {'de': 'claude'});
      final gemini = _GeneradorFalso(datos: {'de': 'gemini'});
      final g = GeneradorConRespaldo(principal: claude, respaldo: gemini);
      final r = await g.generarJson(sistema: 's', mensaje: 'm', esquema: {});
      expect(r['de'], 'claude');
      expect(gemini.llamadas, 0);
    });

    test('si Claude falla, responde Gemini', () async {
      final claude = _GeneradorFalso(error: const _Error('HTTP 529'));
      final gemini = _GeneradorFalso(datos: {'de': 'gemini'});
      final g = GeneradorConRespaldo(principal: claude, respaldo: gemini);
      final r = await g.generarJson(sistema: 's', mensaje: 'm', esquema: {});
      expect(r['de'], 'gemini');
      expect(claude.llamadas, 1);
    });

    test('si fallan los dos, llega el error de Gemini', () async {
      final g = GeneradorConRespaldo(
        principal: _GeneradorFalso(error: const _Error('claude')),
        respaldo: _GeneradorFalso(error: const _Error('gemini')),
      );
      await expectLater(
        g.generarJson(sistema: 's', mensaje: 'm', esquema: {}),
        throwsA(isA<_Error>().having((e) => e.motivo, 'motivo', 'gemini')),
      );
    });

    test(
      '"Más info" con Claude sigue pasando por el filtro de veredictos',
      () async {
        final claude = _GeneradorFalso(
          datos: {
            'que_es': 'Es un endulzante. Es apto para celíacos.',
            'origen': 'De la caña.',
            'donde_aparece': 'Golosinas.',
          },
        );
        final info = await ServicioInfoIngredienteIA.conGenerador(claude)
            .explicar(
              const SolicitudInfoIngrediente(
                ingrediente: 'azucar',
                estado: EstadoIngrediente.noChoca,
                restriccionesPerfil: ['cereales con gluten'],
              ),
            );
        expect(info.queEs, 'Es un endulzante.');
      },
    );
  });
}
