import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';

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

  testWidgets('el aviso informativo aparece siempre', (tester) async {
    await montar(tester, ocr([('Ingredientes: sal.', 0.95)]));
    expect(find.textContaining('informativa'), findsWidgets);
  });
}
