import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/modelo/resultado_analisis.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';

import 'ayuda_base.dart';

/// Semáforo por perfil: rojo si una restricción coincide, verde solo si todo
/// quedó verificado para ese perfil, ámbar si faltó verificar algo.
void main() {
  final analizador = Analizador(cargarBaseReal());

  const celiaco = Perfil(
    nombre: 'Mateo (celíaco)',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'trigo',
        severidad: Severidad.moderada,
      ),
    ],
  );
  const leche = Perfil(
    nombre: 'Sofía (leche)',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'leche',
        severidad: Severidad.anafilaxia,
      ),
    ],
  );

  ResultadoAnalisis analizar(String texto, List<Perfil> perfiles) =>
      analizador.analizar(
        LecturaOcr([LineaOcr(texto: texto, confianza: 0.95, indice: 0)]),
        perfilesActivos: perfiles,
      );

  SemaforoPerfil de(ResultadoAnalisis r, Perfil p) =>
      r.semaforos.singleWhere((s) => s.perfil == p.nombre);

  group('color por perfil', () {
    test('el mismo producto es rojo para un perfil y verde para otro', () {
      final r = analizar('Ingredientes: harina de trigo, azúcar, sal.', const [
        celiaco,
        leche,
      ]);
      expect(r.semaforos, hasLength(2));
      expect(de(r, celiaco).color, ColorSemaforo.rojo);
      expect(de(r, leche).color, ColorSemaforo.verde);
    });

    test('rojo cuando una o más restricciones coinciden', () {
      final r = analizar('Ingredientes: harina de trigo, leche, sal.', const [
        celiaco,
        leche,
      ]);
      expect(de(r, celiaco).color, ColorSemaforo.rojo);
      expect(de(r, leche).color, ColorSemaforo.rojo);
    });

    test('un ingrediente no reconocido impide el verde (regla 1.3)', () {
      final r = analizar('Ingredientes: azúcar, quinotos.', const [leche]);
      final s = de(r, leche);
      expect(s.color, ColorSemaforo.ambar);
      expect(s.motivos.join(), contains('No reconocimos "quinotos"'));
    });

    test('una línea ilegible impide el verde', () {
      final r = analizador.analizar(
        const LecturaOcr([
          LineaOcr(
            texto: 'Ingredientes: azúcar, sal.',
            confianza: 0.95,
            indice: 0,
          ),
          LineaOcr(texto: 'borroso', confianza: 0.1, indice: 1),
        ]),
        perfilesActivos: const [leche],
      );
      expect(de(r, leche).color, ColorSemaforo.ambar);
    });

    test('"puede contener" un alérgeno del perfil impide el verde', () {
      final r = analizar(
        'Ingredientes: azúcar, sal. Puede contener leche.',
        const [leche, celiaco],
      );
      expect(de(r, leche).color, ColorSemaforo.ambar);
      expect(de(r, leche).motivos.join(), contains('puede contener leche'));
      // Las trazas de leche no afectan al perfil celíaco.
      expect(de(r, celiaco).color, ColorSemaforo.verde);
    });

    test('lo declarado en CONTIENE cuenta como coincidencia', () {
      final r = analizar('Ingredientes: azúcar. Contiene leche.', const [
        leche,
      ]);
      final s = de(r, leche);
      expect(s.color, ColorSemaforo.rojo);
      expect(
        s.ingredientes.where((i) => i.estado == EstadoIngrediente.choca),
        isNotEmpty,
      );
    });

    test('un alérgeno que la base no cubre nunca da verde', () {
      // La base mínima no tiene ningún ingrediente de crustáceos.
      const crustaceos = Perfil(
        nombre: 'Crustáceos',
        restricciones: [
          RestriccionPerfil(
            grupoAlergenoId: 'crustaceos',
            severidad: Severidad.anafilaxia,
          ),
        ],
      );
      final r = Analizador(baseMinima()).analizar(
        const LecturaOcr([
          LineaOcr(texto: 'Ingredientes: sal.', confianza: 0.95, indice: 0),
        ]),
        perfilesActivos: const [crustaceos],
      );
      final s = r.semaforos.single;
      expect(s.color, ColorSemaforo.ambar);
      expect(s.motivos.join(), contains('Todavía no sabemos detectar'));
    });

    test('sin perfiles activos no hay semáforo', () {
      expect(analizar('Ingredientes: sal.', const []).semaforos, isEmpty);
    });
  });

  test('detalle: cada ingrediente en rojo, verde o no reconocido', () {
    final r = analizar(
      'Ingredientes: harina de trigo, azúcar, quinotos.',
      const [celiaco],
    );
    final estados = {
      for (final i in de(r, celiaco).ingredientes) i.texto: i.estado,
    };
    expect(estados['harina de trigo'], EstadoIngrediente.choca);
    expect(estados['azucar'], EstadoIngrediente.noChoca);
    expect(estados['quinotos'], EstadoIngrediente.noReconocido);
    final harina = de(
      r,
      celiaco,
    ).ingredientes.firstWhere((i) => i.texto == 'harina de trigo');
    expect(harina.motivo, 'cereales con gluten');
  });

  group('textos para la persona', () {
    test('el titular usa el nombre de pila', () {
      final r = analizar('Ingredientes: harina de trigo, azúcar, sal.', const [
        celiaco,
        leche,
      ]);
      expect(de(r, celiaco).titular, 'No es seguro para Mateo');
      expect(de(r, leche).titular, 'Sofía puede consumir este producto');
    });

    test('en rojo dice qué ingrediente es el problema', () {
      final r = analizar('Ingredientes: harina de trigo, sal.', const [
        celiaco,
      ]);
      expect(
        de(r, celiaco).motivos.single,
        'Contiene harina de trigo (cereales con gluten).',
      );
    });

    test('en ámbar dice qué hacer', () {
      final r = analizar('Ingredientes: azúcar, quinotos.', const [leche]);
      expect(de(r, leche).titular, 'Revisalo antes de que Sofía lo consuma');
      expect(de(r, leche).motivos.single, contains('Fijate en la etiqueta'));
    });

    test('nombre corto: saca lo que va entre paréntesis', () {
      expect(SemaforoPerfil.nombreCorto('Sofía (alergia a la leche)'), 'Sofía');
      expect(
        SemaforoPerfil.nombreCorto('Intolerancia a sulfitos'),
        'Intolerancia a sulfitos',
      );
      expect(SemaforoPerfil.nombreCorto('(sin nombre)'), '(sin nombre)');
    });
  });

  testWidgets('la pantalla muestra el semáforo de cada perfil y su detalle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final r = analizar('Ingredientes: harina de trigo, azúcar, sal.', const [
      celiaco,
      leche,
    ]);
    await tester.pumpWidget(MaterialApp(home: PantallaResultado(resultado: r)));

    expect(find.text('Mateo (celíaco)'), findsOneWidget);
    expect(find.text('No es seguro para Mateo'), findsOneWidget);
    expect(find.text('Sofía (leche)'), findsOneWidget);
    expect(find.text('Sofía puede consumir este producto'), findsOneWidget);

    // El semáforo está arriba del análisis completo (los tres bloques).
    expect(
      tester.getTopLeft(find.text('Mateo (celíaco)')).dy,
      lessThan(tester.getTopLeft(find.text('Ver análisis completo')).dy),
    );

    // El detalle de ingredientes se abre con el acordeón.
    expect(find.text('Contiene cereales con gluten'), findsNothing);
    await tester.tap(
      find.textContaining('Ver ingredientes (3) · 1 con problema'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contiene cereales con gluten'), findsOneWidget);
  });
}
