import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/cuenta/servicio_cuenta.dart';
import 'package:safelabel/datos/almacen_local.dart';
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/datos/repositorio_usuarios.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/modelo/usuario.dart';
import 'package:safelabel/ui/avatar.dart';
import 'package:safelabel/ui/editor_perfil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayuda_base.dart';

/// Avatares de perfiles y de la cuenta: se guardan, sobreviven a la migración
/// de la base y se eligen desde la pantalla tipo Netflix.
void main() {
  final base = cargarBaseReal();
  final grupos = base.grupos.keys.toSet();
  const leche = RestriccionPerfil(
    grupoAlergenoId: 'leche',
    severidad: Severidad.anafilaxia,
  );

  setUpAll(sqfliteFfiInit);

  group('perfiles', () {
    test('sin avatar elegido, se dibuja a partir del nombre', () {
      const p = Perfil(nombre: 'Sofía', restricciones: []);
      expect(p.semillaAvatar, 'Sofía');
      expect(p.copiarCon(avatar: 'safelabel-4').semillaAvatar, 'safelabel-4');
    });

    test('el avatar se guarda y se edita en SQLite', () async {
      final bd = await BdLocal.abrir(
        fabrica: databaseFactoryFfi,
        ruta: inMemoryDatabasePath,
      );
      addTearDown(bd.close);
      final repo = RepositorioPerfilesSqlite(bd, gruposValidos: grupos);

      final creado = await repo.crear(
        const Perfil(
          nombre: 'Sofía',
          restricciones: [leche],
          avatar: 'safelabel-3',
        ),
      );
      expect((await repo.obtenerTodos()).single.avatar, 'safelabel-3');

      await repo.actualizar(creado.copiarCon(avatar: 'safelabel-9'));
      expect((await repo.obtenerTodos()).single.avatar, 'safelabel-9');
      expect((await repo.obtenerActivos()), isEmpty);
    });

    test('la migración conserva los perfiles de una base vieja', () async {
      final dir = await Directory.systemTemp.createTemp('safelabel_avatar');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = p.join(dir.path, 'vieja.db');

      // Base como la dejaba la versión 1 de la app, sin columna avatar.
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE perfil (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'nombre TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE restriccion_perfil (perfil_id INTEGER NOT NULL '
              'REFERENCES perfil(id) ON DELETE CASCADE, grupo_alergeno_id '
              'TEXT NOT NULL, severidad TEXT NOT NULL, PRIMARY KEY '
              '(perfil_id, grupo_alergeno_id))',
            );
            await db.execute(
              'CREATE TABLE perfil_activo (perfil_id INTEGER PRIMARY KEY '
              'REFERENCES perfil(id) ON DELETE CASCADE)',
            );
          },
        ),
      );
      await vieja.insert('perfil', {'nombre': 'Mateo'});
      await vieja.insert('restriccion_perfil', {
        'perfil_id': 1,
        'grupo_alergeno_id': 'trigo',
        'severidad': 'moderada',
      });
      await vieja.close();

      final bd = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
      addTearDown(bd.close);
      final perfiles = await RepositorioPerfilesSqlite(
        bd,
        gruposValidos: grupos,
      ).obtenerTodos();

      expect(perfiles.single.nombre, 'Mateo');
      expect(perfiles.single.restricciones.single.grupoAlergenoId, 'trigo');
      expect(perfiles.single.avatar, '');
      expect(perfiles.single.semillaAvatar, 'Mateo');
    });
  });

  group('cuenta', () {
    Future<ServicioCuenta> servicio() async {
      SharedPreferences.setMockInitialValues({});
      return ServicioCuenta(RepositorioUsuarios(await AlmacenLocal.abrir()));
    }

    test('el avatar se elige al registrarse y se puede cambiar', () async {
      final s = await servicio();
      final cuenta = await s.registrar(
        nombre: 'Ana',
        apellido: 'Pérez',
        email: 'ana@mail.com',
        fechaNacimiento: DateTime(1995, 3, 15),
        contrasena: 'secreta123',
        aceptaTerminos: true,
        avatar: 'safelabel-5',
      );
      expect(cuenta.semillaAvatar, 'safelabel-5');

      await s.cambiarAvatar('safelabel-11');
      expect(s.cuentaActual()!.semillaAvatar, 'safelabel-11');
    });

    test('una cuenta guardada antes de los avatares sigue cargando', () {
      final u = Usuario.desdeMapa({
        'id': '1',
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'email': 'ana@mail.com',
        'hashContrasena': 'h',
        'salt': 's',
        'fechaAlta': DateTime(2026).toIso8601String(),
      });
      expect(u.avatar, '');
      expect(Usuario.desdeMapa(u.copiarCon(avatar: 'x').aMapa()).avatar, 'x');
    });
  });

  group('pantalla', () {
    test('las sugerencias son siempre las mismas para el mismo lote', () {
      expect(semillasSugeridas(0), semillasSugeridas(0));
      expect(semillasSugeridas(0), hasLength(12));
      expect(semillasSugeridas(1).first, isNot(semillasSugeridas(0).first));
    });

    testWidgets('en el editor se toca el avatar, se elige otro y se guarda', (
      tester,
    ) async {
      // Pantalla alta: el botón "Guardar" queda al final de la lista.
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = RepositorioPerfilesMemoria(gruposValidos: grupos);
      await tester.pumpWidget(
        MaterialApp(
          home: EditorPerfil(repositorio: repo, base: base),
        ),
      );
      await tester.enterText(find.byKey(const Key('nombre_perfil')), 'Juli');

      await tester.tap(find.byKey(const Key('selector_avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Elegí el avatar del perfil'), findsOneWidget);

      final elegido = semillasSugeridas(0)[5];
      await tester.tap(find.byKey(Key('avatar_$elegido')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await repo.obtenerTodos()).single.avatar, elegido);
    });
  });
}
