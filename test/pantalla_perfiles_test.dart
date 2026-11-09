import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/conocimiento/catalogo_conocimiento.dart';
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/perfiles_iniciales.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ui/editor_perfil.dart';
import 'package:safelabel/ui/pantalla_inicio.dart';
import 'package:safelabel/ui/pantalla_perfiles.dart';
import 'package:safelabel/ui/tema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safelabel/datos/repositorio_conocimiento.dart';

import 'ayuda_base.dart';

void main() {
  final base = cargarBaseReal();
  final gruposValidos = base.grupos.keys.toSet();
  final catalogo = CatalogoConocimiento.desdeBaseLegacy(base);

  late RepositorioPerfilesMemoria repo;
  late Database bdConocimiento;
  late RepositorioConocimiento conocimiento;

  setUp(() async {
    sqfliteFfiInit();

    repo = RepositorioPerfilesMemoria(gruposValidos: gruposValidos);

    bdConocimiento = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    conocimiento = RepositorioConocimiento(bdConocimiento);
  });

  tearDown(() async {
    await bdConocimiento.close();
  });

  Future<void> montar(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: temaApp, home: pantalla));
    await tester.pumpAndSettle();
  }

  Future<void> elegirSeveridad(
    WidgetTester tester,
    String grupoId,
    String opcion,
  ) async {
    await tester.tap(find.byKey(Key('severidad_$grupoId')));
    await tester.pumpAndSettle();
    // El menú abierto duplica el texto de la opción seleccionada: la última
    // coincidencia es la del menú.
    await tester.tap(find.text(opcion).last);
    await tester.pumpAndSettle();
  }

  group('perfiles iniciales', () {
    test('cumplen las validaciones contra la base real', () {
      for (final p in perfilesIniciales) {
        expect(() => validarPerfil(p, gruposValidos), returnsNormally);
      }
    });

    test('se siembran todos y queda activo el primero', () async {
      await sembrarPerfilesIniciales(repo);
      final todos = await repo.obtenerTodos();
      expect(
        todos.map((p) => p.nombre),
        perfilesIniciales.map((p) => p.nombre),
      );
      expect((await repo.obtenerActivos()).single.nombre, todos.first.nombre);
    });

    test('alCrear corre solo la primera vez que se abre la base', () async {
      sqfliteFfiInit();
      final temporal = Directory.systemTemp.createTempSync('safelabel_');
      addTearDown(() => temporal.deleteSync(recursive: true));
      final ruta = p.join(temporal.path, BdLocal.nombreArchivo);

      var creaciones = 0;
      for (var i = 0; i < 2; i++) {
        final bd = await BdLocal.abrir(
          fabrica: databaseFactoryFfi,
          ruta: ruta,
          alCrear: () => creaciones++,
        );
        await bd.close();
      }
      expect(creaciones, 1);
    });
  });

  group('editor', () {
    testWidgets('lista todos los grupos de la base, sin texto libre', (
      tester,
    ) async {
      await montar(tester, EditorPerfil(repositorio: repo, base: base));

      expect(base.grupos, hasLength(9));
      for (final g in base.grupos.values) {
        expect(find.byKey(Key('severidad_${g.id}')), findsOneWidget);
        expect(find.text(g.nombre), findsOneWidget);
      }
      // El único campo de texto es el nombre.
      expect(find.byType(TextField), findsOneWidget);
      // Nada de tildes: la severidad no se elige con casillas (regla 1.4).
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('crea un perfil con nombre, grupos y severidades', (
      tester,
    ) async {
      await montar(tester, EditorPerfil(repositorio: repo, base: base));

      await tester.enterText(find.byKey(const Key('nombre_perfil')), 'Ana');
      await elegirSeveridad(tester, 'leche', 'Anafilaxia');
      await elegirSeveridad(tester, 'mani', 'Leve');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final guardado = (await repo.obtenerTodos()).single;
      expect(guardado.nombre, 'Ana');
      expect(guardado.severidadPara('leche'), Severidad.anafilaxia);
      expect(guardado.severidadPara('mani'), Severidad.leve);
      expect(guardado.restricciones, hasLength(2));
    });

    testWidgets('editar carga lo guardado y permite quitar una restricción', (
      tester,
    ) async {
      final creado = await repo.crear(
        const Perfil(
          nombre: 'Juli',
          restricciones: [
            RestriccionPerfil(
              grupoAlergenoId: 'mani',
              severidad: Severidad.anafilaxia,
            ),
            RestriccionPerfil(
              grupoAlergenoId: 'soja',
              severidad: Severidad.leve,
            ),
          ],
        ),
      );
      await montar(
        tester,
        EditorPerfil(repositorio: repo, base: base, perfil: creado),
      );

      expect(find.text('Juli'), findsOneWidget);
      await elegirSeveridad(tester, 'soja', 'Sin restricción');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final guardado = (await repo.obtenerTodos()).single;
      expect(guardado.id, creado.id);
      expect(guardado.restringe('soja'), isFalse);
      expect(guardado.severidadPara('mani'), Severidad.anafilaxia);
    });

    testWidgets('muestra el error de validación y no guarda', (tester) async {
      await montar(tester, EditorPerfil(repositorio: repo, base: base));

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('El perfil necesita un nombre.'), findsOneWidget);
      expect(await repo.obtenerTodos(), isEmpty);
    });

    testWidgets('señala un grupo que ya no existe en la base', (tester) async {
      // Simula un perfil guardado antes de que un release quitara un grupo.
      const viejo = Perfil(
        id: '1',
        nombre: 'Viejo',
        restricciones: [
          RestriccionPerfil(
            grupoAlergenoId: 'lactosa',
            severidad: Severidad.moderada,
          ),
        ],
      );
      await montar(
        tester,
        EditorPerfil(repositorio: repo, base: base, perfil: viejo),
      );

      expect(find.textContaining('"lactosa" ya no existe'), findsOneWidget);
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"lactosa" ya no existe'), findsNothing);
    });
  });

  group('lista de perfiles', () {
    testWidgets('el borrado pide confirmación en la propia tarjeta', (
      tester,
    ) async {
      await sembrarPerfilesIniciales(repo);
      await montar(tester, PantallaPerfiles(repositorio: repo, base: base));

      final nombre = perfilesIniciales.first.nombre;
      expect(find.text(nombre), findsOneWidget);

      // Primer toque: pide confirmación, todavía no borra.
      await tester.tap(find.byTooltip('Eliminar').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Eliminar "$nombre"?'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await repo.obtenerTodos(), hasLength(4));

      // Cancelar vuelve a la tarjeta normal.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text(nombre), findsOneWidget);
      expect(await repo.obtenerTodos(), hasLength(4));

      // Confirmar borra.
      await tester.tap(find.byTooltip('Eliminar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text(nombre), findsNothing);
      expect(await repo.obtenerTodos(), hasLength(3));
    });

    testWidgets('muestra los nombres de grupo de la base', (tester) async {
      await repo.crear(
        const Perfil(
          nombre: 'Mateo',
          restricciones: [
            RestriccionPerfil(
              grupoAlergenoId: 'trigo',
              severidad: Severidad.moderada,
            ),
          ],
        ),
      );
      await montar(tester, PantallaPerfiles(repositorio: repo, base: base));

      expect(
        find.text('${base.grupo('trigo')!.nombre} (moderada)'),
        findsOneWidget,
      );
    });

    testWidgets('editar desde la lista y volver muestra el cambio', (
      tester,
    ) async {
      await repo.crear(const Perfil(nombre: 'Ana', restricciones: []));
      await montar(tester, PantallaPerfiles(repositorio: repo, base: base));

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('nombre_perfil')), 'Ana B.');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ana B.'), findsOneWidget);
    });
  });

  group('inicio', () {
    testWidgets('lee los perfiles del repositorio y guarda la selección', (
      tester,
    ) async {
      await sembrarPerfilesIniciales(repo);
      await montar(
        tester,
        PantallaInicio(
          base: base,
          repositorio: repo,
          conocimiento: conocimiento,
          catalogo: catalogo,
        ),
      );

      for (final p in perfilesIniciales) {
        expect(find.text(p.nombre), findsOneWidget);
      }

      final segundo = perfilesIniciales[1].nombre;
      await tester.tap(find.text(segundo));
      await tester.pumpAndSettle();

      final activos = await repo.obtenerActivos();
      expect(activos.map((p) => p.nombre), [
        perfilesIniciales[0].nombre,
        segundo,
      ]);
    });

    testWidgets('la selección sobrevive a volver a montar la pantalla', (
      tester,
    ) async {
      await sembrarPerfilesIniciales(repo);
      final todos = await repo.obtenerTodos();
      await repo.marcarActivos({todos[2].id});

      // Objetos nuevos en cada lectura: la selección tiene que reconocerse por
      // id, no por identidad.
      await montar(
        tester,
        PantallaInicio(
          base: base,
          repositorio: repo,
          conocimiento: conocimiento,
          catalogo: catalogo,
        ),
      );
      await tester.tap(find.text(todos[3].nombre));
      await tester.pumpAndSettle();

      expect((await repo.obtenerActivos()).map((p) => p.id), [
        todos[2].id,
        todos[3].id,
      ]);
    });

    testWidgets('sin perfiles invita a crear uno', (tester) async {
      await montar(
        tester,
        PantallaInicio(
          base: base,
          repositorio: repo,
          conocimiento: conocimiento,
          catalogo: catalogo,
        ),
      );
      expect(find.textContaining('No hay perfiles guardados'), findsOneWidget);
    });
  });
}
