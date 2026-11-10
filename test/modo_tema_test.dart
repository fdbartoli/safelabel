import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/datos/almacen_local.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/ui/controlador_tema.dart';
import 'package:safelabel/ui/pantalla_resultado.dart';
import 'package:safelabel/ui/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayuda_base.dart';

/// Modo claro / oscuro: botón en la barra, preferencia guardada.
void main() {
  Future<AlmacenLocal> almacen([Map<String, Object> valores = const {}]) {
    SharedPreferences.setMockInitialValues(valores);
    return AlmacenLocal.abrir();
  }

  test('sin elección, sigue el modo del teléfono', () async {
    expect(ControladorTema(await almacen()).modo, ThemeMode.system);
  });

  test('alterna al modo opuesto al que se ve y lo recuerda', () async {
    final a = await almacen();
    final c = ControladorTema(a);

    await c.alternar(Brightness.light);
    expect(c.modo, ThemeMode.dark);
    // Al reabrir la app se lee lo guardado.
    expect(ControladorTema(a).modo, ThemeMode.dark);

    await c.alternar(Brightness.dark);
    expect(c.modo, ThemeMode.light);
    expect(ControladorTema(a).modo, ThemeMode.light);
  });

  testWidgets('el botón cambia toda la app a oscuro y de vuelta a claro', (
    tester,
  ) async {
    final c = ControladorTema(await almacen({ControladorTema.clave: 'claro'}));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: c,
        builder: (_, _) => MaterialApp(
          theme: temaApp,
          darkTheme: temaAppOscuro,
          themeMode: c.modo,
          home: Scaffold(
            appBar: AppBar(actions: [BotonModoTema(controlador: c)]),
          ),
        ),
      ),
    );
    Brightness brillo() =>
        Theme.of(tester.element(find.byType(Scaffold))).brightness;

    expect(brillo(), Brightness.light);
    expect(find.byTooltip('Modo oscuro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_modo_tema')));
    await tester.pumpAndSettle();
    expect(brillo(), Brightness.dark);
    expect(find.byTooltip('Modo claro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_modo_tema')));
    await tester.pumpAndSettle();
    expect(brillo(), Brightness.light);
  });

  testWidgets('en modo oscuro el resultado usa el tema neutro oscuro', (
    tester,
  ) async {
    final resultado = Analizador(baseMinima()).analizar(
      const LecturaOcr([
        LineaOcr(texto: 'Ingredientes: sal.', confianza: 0.95, indice: 0),
      ]),
      perfilesActivos: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: temaApp,
        darkTheme: temaAppOscuro,
        themeMode: ThemeMode.dark,
        home: PantallaResultado(resultado: resultado),
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, temaResultadoOscuro.colorScheme.primary);
    expect(scheme.primary, isNot(temaAppOscuro.colorScheme.primary));
  });
}
