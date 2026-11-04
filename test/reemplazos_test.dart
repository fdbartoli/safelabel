import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/sugerencias/filtro_reemplazos.dart';
import 'package:safelabel/sugerencias/gestor_reemplazos.dart';
import 'package:safelabel/sugerencias/servicio_reemplazos.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';

import 'ayuda_base.dart';

class _ServicioFalso implements ServicioReemplazos {
  _ServicioFalso(this.respuesta, {this.error});
  final RespuestaReemplazos respuesta;
  final Object? error;
  SolicitudReemplazo? ultima;

  @override
  Future<RespuestaReemplazos> sugerir(SolicitudReemplazo s) async {
    ultima = s;
    if (error != null) throw error!;
    return respuesta;
  }
}

SugerenciaReemplazo _s(String nombre) =>
    SugerenciaReemplazo(nombre: nombre, motivo: 'motivo');

void main() {
  final base = cargarBaseReal();

  const aplvYFrutosSecos = Perfil(
    nombre: 'Sofi',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'leche',
        severidad: Severidad.anafilaxia,
      ),
      RestriccionPerfil(
        grupoAlergenoId: 'frutos_secos',
        severidad: Severidad.anafilaxia,
      ),
    ],
  );
  const celiaco = Perfil(
    nombre: 'Mateo',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'trigo',
        severidad: Severidad.moderada,
      ),
    ],
  );

  group('FiltroReemplazos (red de seguridad determinista)', () {
    test(
      'descarta lo que nombra un alérgeno restringido, incluso en plural',
      () {
        final f = FiltroReemplazos(base, [aplvYFrutosSecos]);
        final r = f.filtrar([
          _s('Bebida de almendras'),
          _s('Leche de coco'),
          _s('Bebida de arroz'),
        ]);
        expect(r.aceptadas.map((s) => s.nombre), ['Bebida de arroz']);
        expect(
          r.descartadas.map((d) => d.grupoAlergeno),
          containsAll(['frutas secas de árbol', 'leche']),
        );
      },
    );

    test('para celíacos descarta avena y cebada (fórmula argentina)', () {
      final f = FiltroReemplazos(base, [celiaco]);
      final r = f.filtrar([
        _s('Galletitas de avena'),
        _s('Copos de cebada'),
        _s('Galletas de arroz'),
        _s('Tostadas de maíz'),
      ]);
      expect(r.aceptadas.map((s) => s.nombre), [
        'Galletas de arroz',
        'Tostadas de maíz',
      ]);
    });

    test('no descarta lo que solo restringe otro perfil inactivo', () {
      final f = FiltroReemplazos(base, [celiaco]);
      final r = f.filtrar([_s('Bebida de almendras')]);
      expect(r.aceptadas, hasLength(1));
    });
  });

  group('ServicioReemplazosGemini (sin red)', () {
    const solicitud = SolicitudReemplazo(
      gruposRestringidos: ['leche'],
      ingredientesConflictivos: ['leche'],
      ingredientesLeidos: ['leche', 'azucar'],
    );

    Map<String, dynamic> respuestaOk(
      Map<String, dynamic> datos, {
      String fin = 'STOP',
    }) => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'razonamiento interno', 'thought': true},
              {'text': jsonEncode(datos)},
            ],
          },
          'finishReason': fin,
        },
      ],
    };

    for (final estado in [200, 400, 401, 403, 404, 429, 500, 503]) {
      test('HTTP $estado: respaldo solo ante 503', () async {
        final pedidos = <http.Request>[];
        final cliente = MockClient((pedido) async {
          pedidos.add(pedido);
          if (pedidos.length == 1 && estado != 200) {
            return http.Response('{}', estado);
          }
          return http.Response(
            jsonEncode(
              respuestaOk({
                'tipo_producto': 'bebida',
                'sugerencias': [
                  {'nombre': 'Bebida de arroz', 'motivo': 'Idea para buscar.'},
                ],
              }),
            ),
            200,
          );
        });
        addTearDown(cliente.close);
        final servicio = ServicioReemplazosGemini(
          apiKey: 'clave-ficticia',
          cliente: cliente,
        );
        if (estado == 200 || estado == 503) {
          final resultado = await servicio.sugerir(solicitud);
          expect(resultado.sugerencias.single.nombre, 'Bebida de arroz');
        } else {
          await expectLater(
            servicio.sugerir(solicitud),
            throwsA(isA<ErrorReemplazos>()),
          );
        }
        expect(pedidos, hasLength(estado == 503 ? 2 : 1));
        expect(
          pedidos.first.url.path,
          '/v1beta/models/gemini-3.8-flash:generateContent',
        );
        if (estado == 503) {
          expect(
            pedidos.last.url.path,
            '/v1beta/models/gemini-3.5-flash-lite:generateContent',
          );
          expect(pedidos.last.body, pedidos.first.body);
        }
        for (final pedido in pedidos) {
          expect(pedido.headers['x-goog-api-key'], 'clave-ficticia');
        }
      });
    }

    test(
      'si el respaldo también devuelve 503, informa error sin bucle',
      () async {
        var llamadas = 0;
        final cliente = MockClient((_) async {
          llamadas++;
          return http.Response('{}', 503);
        });
        addTearDown(cliente.close);
        final servicio = ServicioReemplazosGemini(
          apiKey: 'clave-ficticia',
          cliente: cliente,
        );
        await expectLater(
          servicio.sugerir(solicitud),
          throwsA(
            isA<ErrorReemplazos>().having(
              (e) => e.motivo,
              'motivo',
              'HTTP 503',
            ),
          ),
        );
        expect(llamadas, 2);
      },
    );

    test('un error de conexión no activa el respaldo', () async {
      var llamadas = 0;
      final cliente = MockClient((_) async {
        llamadas++;
        throw http.ClientException('sin conexión');
      });
      addTearDown(cliente.close);
      final servicio = ServicioReemplazosGemini(
        apiKey: 'clave-ficticia',
        cliente: cliente,
      );
      await expectLater(
        servicio.sugerir(solicitud),
        throwsA(isA<ErrorReemplazos>()),
      );
      expect(llamadas, 1);
    });

    test('el cuerpo manda solo texto y pide salida JSON con esquema', () {
      final cuerpo = ServicioReemplazosGemini.construirCuerpo(
        const SolicitudReemplazo(
          gruposRestringidos: ['leche'],
          ingredientesConflictivos: ['dulce de leche (leche)'],
          ingredientesLeidos: ['harina de trigo', 'dulce de leche'],
        ),
      );
      expect(
        cuerpo['generationConfig']['responseMimeType'],
        'application/json',
      );
      expect(cuerpo['generationConfig']['responseSchema']['type'], 'OBJECT');
      final contenido = jsonEncode(cuerpo['contents']);
      expect(contenido, contains('dulce de leche'));
      // Regla 1.2: solo partes de texto, nunca una imagen.
      expect(contenido, isNot(contains('inlineData')));
      expect(contenido, isNot(contains('inline_data')));
      expect(contenido, isNot(contains('fileData')));
    });

    test('la clave va en el header, no en la URL', () {
      final h = ServicioReemplazosGemini.construirHeaders('k');
      expect(h['x-goog-api-key'], 'k');
    });

    test('parsea la salida estructurada e ignora el razonamiento', () {
      final r = ServicioReemplazosGemini.parsearRespuesta(
        respuestaOk({
          'tipo_producto': 'galletitas dulces',
          'sugerencias': [
            {'nombre': 'Galletas de arroz', 'motivo': 'Sin trigo.'},
          ],
        }),
      );
      expect(r.tipoProducto, 'galletitas dulces');
      expect(r.sugerencias.single.nombre, 'Galletas de arroz');
    });

    test(
      'un bloqueo de seguridad es un error controlado, no una lista vacía',
      () {
        expect(
          () => ServicioReemplazosGemini.parsearRespuesta({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
          throwsA(isA<ErrorReemplazos>()),
        );
        expect(
          () => ServicioReemplazosGemini.parsearRespuesta(
            respuestaOk({
              'tipo_producto': '',
              'sugerencias': [],
            }, fin: 'SAFETY'),
          ),
          throwsA(isA<ErrorReemplazos>()),
        );
      },
    );

    test('una respuesta cortada por límite de tokens es un error', () {
      expect(
        () => ServicioReemplazosGemini.parsearRespuesta(
          respuestaOk({
            'tipo_producto': '',
            'sugerencias': [],
          }, fin: 'MAX_TOKENS'),
        ),
        throwsA(isA<ErrorReemplazos>()),
      );
    });
  });

  group('GestorReemplazos', () {
    LecturaOcr ocr(String t) =>
        LecturaOcr([LineaOcr(texto: t, confianza: 0.95, indice: 0)]);

    test('solo aplica si hay coincidencias, y filtra la respuesta', () async {
      final servicio = _ServicioFalso(
        RespuestaReemplazos(
          tipoProducto: 'galletitas',
          sugerencias: [_s('Galletitas de avena'), _s('Galletas de arroz')],
        ),
      );
      final gestor = GestorReemplazos(
        base: base,
        perfilesActivos: [celiaco],
        servicio: servicio,
      );

      final sinChoque = Analizador(
        base,
      ).analizar(ocr('Ingredientes: sal, azucar.'), perfilesActivos: [celiaco]);
      expect(gestor.aplica(sinChoque), isFalse);

      final conChoque = Analizador(base).analizar(
        ocr('Ingredientes: harina de trigo, azucar, sal.'),
        perfilesActivos: [celiaco],
      );
      expect(gestor.aplica(conChoque), isTrue);

      final r = await gestor.obtener(conChoque);
      expect(r.sugerencias.map((s) => s.nombre), ['Galletas de arroz']);
      expect(r.descartadas.single.nombre, 'Galletitas de avena');
      expect(servicio.ultima!.ingredientesLeidos, contains('harina de trigo'));
    });
  });

  group('Sección en la pantalla de resultado', () {
    Future<void> montar(
      WidgetTester tester,
      GestorReemplazos gestor,
      String texto,
    ) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resultado = Analizador(base).analizar(
        LecturaOcr([LineaOcr(texto: texto, confianza: 0.95, indice: 0)]),
        perfilesActivos: gestor.perfilesActivos,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaResultado(
            resultado: resultado,
            gestorReemplazos: gestor,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final botonSugerir = find.text('Sugerir sustitutos');

    testWidgets(
      'con coincidencias aparece el botón; la IA se llama recién al tocarlo',
      (tester) async {
        final servicio = _ServicioFalso(
          RespuestaReemplazos(
            tipoProducto: 'galletitas',
            sugerencias: [_s('Galletas de arroz')],
          ),
        );
        final gestor = GestorReemplazos(
          base: base,
          perfilesActivos: [celiaco],
          servicio: servicio,
        );
        await montar(tester, gestor, 'Ingredientes: harina de trigo, sal.');

        expect(botonSugerir, findsOneWidget);
        expect(servicio.ultima, isNull);

        await tester.tap(botonSugerir);
        await tester.pumpAndSettle();

        expect(servicio.ultima, isNotNull);
        expect(find.text('Sustitutos para buscar'), findsOneWidget);
        expect(
          find.textContaining('escaneá la etiqueta del sustituto'),
          findsOneWidget,
        );
        expect(find.textContaining('Galletas de arroz'), findsOneWidget);
        // Los tres bloques siguen ahí.
        expect(find.text('Coincidencias con el perfil'), findsOneWidget);
      },
    );

    testWidgets('si la IA falla, avisa y deja reintentar', (tester) async {
      final gestor = GestorReemplazos(
        base: base,
        perfilesActivos: [celiaco],
        servicio: _ServicioFalso(
          RespuestaReemplazos.vacia,
          error: const ErrorReemplazos('sin conexión'),
        ),
      );
      await montar(tester, gestor, 'Ingredientes: harina de trigo, sal.');
      await tester.tap(botonSugerir);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudieron obtener sustitutos'),
        findsOneWidget,
      );
      expect(botonSugerir, findsOneWidget);
      expect(find.text('Coincidencias con el perfil'), findsOneWidget);
    });

    testWidgets('sin conexión configurada, el botón avisa', (tester) async {
      final gestor = GestorReemplazos(
        base: base,
        perfilesActivos: [celiaco],
        servicio: null,
      );
      await montar(tester, gestor, 'Ingredientes: harina de trigo, sal.');
      await tester.tap(botonSugerir);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('todavía no está configurada'),
        findsOneWidget,
      );
    });

    testWidgets('sin coincidencias no hay botón', (tester) async {
      final servicio = _ServicioFalso(RespuestaReemplazos.vacia);
      final gestor = GestorReemplazos(
        base: base,
        perfilesActivos: [celiaco],
        servicio: servicio,
      );
      await montar(tester, gestor, 'Ingredientes: sal, azucar.');
      expect(botonSugerir, findsNothing);
      expect(servicio.ultima, isNull);
    });
  });
}
