import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ocr/guia_captura.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';
import 'package:safelabel/ui/tema.dart';

import 'ayuda_base.dart';

void main() {
  final analizador = Analizador(baseMinima());

  Future<void> montar(WidgetTester tester, LecturaOcr lectura) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resultado = analizador.analizar(
      lectura,
      perfilesActivos: const [
        Perfil(nombre: 'APLV', restricciones: [
          RestriccionPerfil(
              grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
        ]),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: PantallaResultado(resultado: resultado)),
    );
  }

  LecturaOcr ocr(List<(String, double)> l) => LecturaOcr([
        for (var i = 0; i < l.length; i++)
          LineaOcr(texto: l[i].$1, confianza: l[i].$2, indice: i),
      ]);

  testWidgets('muestra los tres bloques en orden y sin veredicto de aptitud',
      (tester) async {
    await montar(
      tester,
      ocr([
        ('Ingredientes: caseinato de sodio, quinotos, sal.', 0.95),
        ('linea borrosa', 0.1),
      ]),
    );

    final tituloB1 = find.text('Coincidencias con el perfil');
    final tituloB2 = find.text('No reconocidos');
    final tituloB3 = find.text('No legibles');
    expect(tituloB1, findsOneWidget);
    expect(tituloB2, findsOneWidget);
    expect(tituloB3, findsOneWidget);
    expect(find.textContaining('2 de 3 ingredientes analizados'), findsOneWidget);

    // Orden: bloque 1 arriba de 2, y 2 arriba de 3.
    final y1 = tester.getTopLeft(tituloB1).dy;
    final y2 = tester.getTopLeft(tituloB2).dy;
    final y3 = tester.getTopLeft(tituloB3).dy;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3));

    // Regla 1.4: ningún ícono que comunique aprobación.
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets(
      'muestra los tres bloques aunque no haya coincidencias ni línea CONTIENE '
      '(reglas 1.3 y 5.5)', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Etiqueta sin línea CONTIENE y con ingredientes que no están en la base:
    // 0 analizados, 0 coincidencias. El resultado se muestra igual.
    final resultado = analizador.analizar(
      ocr([('Ingredientes: agua, colorante caramelo, aroma xyz.', 0.95)]),
      perfilesActivos: const [
        Perfil(nombre: 'APLV', restricciones: [
          RestriccionPerfil(
              grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
        ]),
      ],
    );
    expect(resultado.coincidencias, isEmpty);

    await tester.pumpWidget(MaterialApp(
      home: PantallaResultado(
        resultado: resultado,
        sugerenciasCaptura: const [SugerenciaCaptura.buscarLineaContiene],
      ),
    ));

    expect(find.text('Coincidencias con el perfil'), findsOneWidget);
    expect(find.text('No reconocidos'), findsOneWidget);
    expect(find.text('No legibles'), findsOneWidget);
    // El consejo de captura aparece como aviso, no bloquea.
    expect(find.textContaining('Para una lectura más completa'), findsOneWidget);
  });

  testWidgets(
      'nunca hereda el verde pastel del resto de la app, use el tema que use '
      '(regla 1.4)', (tester) async {
    final resultado = analizador.analizar(
      ocr([('Ingredientes: sal.', 0.95)]),
      perfilesActivos: const [],
    );

    // Se monta bajo el tema general de la app (verde), como pasaría al
    // navegar desde pantalla_captura o pantalla_analisis_texto.
    await tester.pumpWidget(MaterialApp(
      theme: temaApp,
      home: PantallaResultado(resultado: resultado),
    ));

    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    expect(scheme.primary, temaResultado.colorScheme.primary);
    expect(scheme.primary, isNot(temaApp.colorScheme.primary));
  });

  testWidgets('el aviso informativo aparece siempre', (tester) async {
    await montar(tester, ocr([('Ingredientes: sal.', 0.95)]));
    expect(find.textContaining('informativa'), findsWidgets);
  });
}
