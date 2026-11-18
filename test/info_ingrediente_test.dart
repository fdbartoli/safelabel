import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/modelo/semaforo.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/sugerencias/info_ingrediente.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';

import 'ayuda_base.dart';

class _ServicioFalso implements ServicioInfoIngrediente {
  _ServicioFalso({this.error});

  final Exception? error;
  int llamadas = 0;
  SolicitudInfoIngrediente? ultima;

  @override
  Future<InfoIngrediente> explicar(SolicitudInfoIngrediente s) async {
    llamadas++;
    ultima = s;
    if (error != null) throw error!;
    return const InfoIngrediente(
      queEs: 'Harina obtenida de moler el trigo.',
      origen: 'Del grano de trigo.',
      dondeAparece: 'Pan, fideos y galletitas.',
    );
  }
}

void main() {
  const solicitud = SolicitudInfoIngrediente(
    ingrediente: 'harina de trigo',
    estado: EstadoIngrediente.choca,
    chocaCon: 'cereales con gluten',
    restriccionesPerfil: ['cereales con gluten'],
  );

  group('pedido a la IA', () {
    test(
      'manda solo texto, con la determinación de la base como dato fijo',
      () {
        final cuerpo = ServicioInfoIngredienteGemini.construirCuerpo(solicitud);
        final texto = jsonEncode(cuerpo);
        expect(texto, contains('harina de trigo'));
        expect(texto, contains('CHOCA con: cereales con gluten'));
        expect(texto, contains('nunca lo contradigas'));
        expect(texto, isNot(contains('inlineData')));
        expect(
          cuerpo['generationConfig']['responseMimeType'],
          'application/json',
        );
      },
    );

    test('un ingrediente no reconocido se pide como no verificado', () {
      final cuerpo = ServicioInfoIngredienteGemini.construirCuerpo(
        const SolicitudInfoIngrediente(
          ingrediente: 'quinotos',
          estado: EstadoIngrediente.noReconocido,
          restriccionesPerfil: ['leche'],
        ),
      );
      expect(jsonEncode(cuerpo), contains('NO reconoce'));
    });
  });

  group('filtro de veredictos', () {
    test('saca las frases que dicen apto, seguro o "no contiene"', () {
      final info = ServicioInfoIngredienteGemini.desdeDatos({
        'que_es': 'Es un endulzante. Es apto para celíacos.',
        'origen': 'Se obtiene de la caña. No contiene gluten.',
        'donde_aparece': 'Golosinas. Podés consumirlo tranquilo.',
      });
      expect(info.queEs, 'Es un endulzante.');
      expect(info.origen, 'Se obtiene de la caña.');
      expect(info.dondeAparece, 'Golosinas.');
    });

    test('no toca palabras que solo se parecen ("seguramente")', () {
      final info = ServicioInfoIngredienteGemini.desdeDatos({
        'que_es': 'Seguramente lo viste en panificados.',
        'origen': '',
        'donde_aparece': '',
      });
      expect(info.queEs, 'Seguramente lo viste en panificados.');
    });
  });

  group('GestorInfoIngredientes', () {
    test('la misma pregunta se responde una sola vez por sesión', () async {
      final servicio = _ServicioFalso();
      final gestor = GestorInfoIngredientes(servicio);
      await gestor.obtener(solicitud);
      await gestor.obtener(solicitud);
      expect(servicio.llamadas, 1);
    });

    test('un error no queda guardado: reintentar vuelve a preguntar', () async {
      final servicio = _ServicioFalso(
        error: const ErrorInfoIngrediente('HTTP 503'),
      );
      final gestor = GestorInfoIngredientes(servicio);
      await expectLater(gestor.obtener(solicitud), throwsA(anything));
      await expectLater(gestor.obtener(solicitud), throwsA(anything));
      expect(servicio.llamadas, 2);
    });

    test('sin clave avisa que no está configurado', () async {
      final gestor = GestorInfoIngredientes(null);
      expect(gestor.configurado, isFalse);
      await expectLater(
        gestor.obtener(solicitud),
        throwsA(isA<ErrorInfoIngrediente>()),
      );
    });
  });

  group('en la pantalla', () {
    const celiaco = Perfil(
      nombre: 'Mateo (celíaco)',
      restricciones: [
        RestriccionPerfil(
          grupoAlergenoId: 'trigo',
          severidad: Severidad.moderada,
        ),
      ],
    );

    Future<void> abrirMasInfo(
      WidgetTester tester,
      GestorInfoIngredientes gestor,
    ) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = Analizador(cargarBaseReal()).analizar(
        const LecturaOcr([
          LineaOcr(
            texto: 'Ingredientes: harina de trigo, sal.',
            confianza: 0.95,
            indice: 0,
          ),
        ]),
        perfilesActivos: const [celiaco],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaResultado(resultado: r, gestorInfo: gestor),
        ),
      );
      await tester.tap(find.textContaining('Ver ingredientes'));
      await tester.pumpAndSettle();
      // La primera fila es la que choca (van primero).
      await tester.tap(find.text('Más info').first);
      await tester.pumpAndSettle();
    }

    testWidgets('muestra primero lo que dice la base y después la IA', (
      tester,
    ) async {
      final servicio = _ServicioFalso();
      await abrirMasInfo(tester, GestorInfoIngredientes(servicio));

      expect(servicio.ultima?.ingrediente, 'harina de trigo');
      expect(servicio.ultima?.estado, EstadoIngrediente.choca);
      expect(
        find.textContaining('contiene cereales con gluten.'),
        findsOneWidget,
      );
      expect(find.text('Generado por IA'), findsOneWidget);
      expect(find.text('Pan, fideos y galletitas.'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.textContaining('contiene cereales con gluten.'))
            .dy,
        lessThan(tester.getTopLeft(find.text('Generado por IA')).dy),
      );
    });

    testWidgets('sin conexión avisa y deja reintentar', (tester) async {
      await abrirMasInfo(
        tester,
        GestorInfoIngredientes(
          _ServicioFalso(error: const ErrorInfoIngrediente('sin conexión: x')),
        ),
      );
      expect(find.textContaining('Necesitás conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin clave configurada lo avisa', (tester) async {
      await abrirMasInfo(tester, GestorInfoIngredientes(null));
      expect(find.textContaining('no está configurada'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });
}
