import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/diagnostico_ocr.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/ui/pantalla_diagnostico.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';

import 'ayuda_base.dart';

void main() {
  final analizador = Analizador(baseMinima());
  const perfil = Perfil(nombre: 'APLV', restricciones: [
    RestriccionPerfil(grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
  ]);

  final lectura = LecturaOcr(const [
    LineaOcr(
      texto: 'Ingredientes: caselnato de sodlo, quinotos, sal,',
      confianza: 1.0,
      confianzaInformada: false,
      indice: 0,
    ),
    LineaOcr(texto: 'mezcla (harina 000)', confianza: 0.9, indice: 1, bloque: 1),
    LineaOcr(texto: 'linea borrosa', confianza: 0.2, indice: 2, bloque: 1),
  ]);

  group('DiagnosticoOcr desde el analizador', () {
    final d = analizador.analizar(lectura, perfilesActivos: [perfil]).diagnostico!;

    test('conserva todas las líneas del OCR, incluidas las no legibles', () {
      expect(d.lineas, hasLength(3));
      expect(d.esLegible(d.lineas[2]), isFalse);
      expect(d.lineasSinConfianza, 1);
      expect(d.cantidadBloques, 2);
    });

    test('explica qué hizo el matcher con cada ingrediente', () {
      final porTexto = {for (final i in d.items) i.textoOriginal: i};
      expect(porTexto['caselnato de sodlo']!.estado, EstadoItem.difuso);
      expect(porTexto['caselnato de sodlo']!.grupoAlergeno, 'leche');
      expect(porTexto['quinotos']!.estado,
          anyOf(EstadoItem.desconocido, EstadoItem.desconocidoParecido));
      expect(porTexto['sal']!.estado, EstadoItem.exacto);
      expect(porTexto['sal']!.grupoAlergeno, isNull);
      expect(porTexto['harina 000']!.padre, 'mezcla');
    });

    test('el informe en texto trae líneas, confianza e ingredientes', () {
      final t = d.aTexto();
      expect(t, contains('#1 b1 s/d | Ingredientes: caselnato de sodlo'));
      expect(t, contains('[NO LEGIBLE] | linea borrosa'));
      expect(t, contains('no informó confianza en 1 líneas'));
      expect(t, contains('- caselnato de sodlo → parecido'));
      expect(t, contains('(dentro de mezcla)'));
    });
  });

  group('Panel en la pantalla', () {
    testWidgets('el resultado ofrece "Ver texto leído" y abre el panel',
        (tester) async {
      final resultado =
          analizador.analizar(lectura, perfilesActivos: [perfil]);
      await tester.pumpWidget(
          MaterialApp(home: PantallaResultado(resultado: resultado)));

      await tester.tap(find.text('Ver texto leído'));
      await tester.pumpAndSettle();

      expect(find.text('Texto leído'), findsOneWidget);
      expect(find.textContaining('caselnato de sodlo'), findsWidgets);
      expect(find.textContaining('confianza s/d'), findsOneWidget);
      expect(find.textContaining('NO LEGIBLE'), findsOneWidget);
    });

    testWidgets('Copiar pone el informe en el portapapeles', (tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiado = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      final d = analizador
          .analizar(lectura, perfilesActivos: [perfil]).diagnostico!;
      await tester.pumpWidget(
          MaterialApp(home: PantallaDiagnostico(diagnostico: d)));
      await tester.tap(find.text('Copiar'));
      await tester.pump();

      expect(copiado, d.aTexto());
      expect(find.text('Texto leído copiado'), findsOneWidget);
    });
  });
}
