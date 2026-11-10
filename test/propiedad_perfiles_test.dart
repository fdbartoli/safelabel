import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/cuenta/servicio_cuenta.dart';
import 'package:safelabel/datos/almacen_local.dart';
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/preparador_perfiles.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/datos/repositorio_usuarios.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _restricciones = [
  RestriccionPerfil(grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
  RestriccionPerfil(grupoAlergenoId: 'trigo', severidad: Severidad.moderada),
  RestriccionPerfil(grupoAlergenoId: 'mani', severidad: Severidad.leve),
];
const _grupos = {'leche', 'trigo', 'mani'};

Future<CuentaUsuario> _registrar(ServicioCuenta servicio, String email) =>
    servicio.registrar(
      nombre: 'Ana',
      apellido: 'Pérez',
      email: email,
      fechaNacimiento: DateTime(1990),
      contrasena: 'secreta123',
      aceptaTerminos: true,
    );

class _PreparadorConFallo implements PreparadorPerfiles {
  _PreparadorConFallo(this.real, {required this.fallarEn});
  final PreparadorPerfiles real;
  final int fallarEn;
  int llamadas = 0;

  @override
  Future<void> preparar(
    Set<String> usuarios, {
    Set<String> usuariosConDemostracion = const {},
  }) async {
    if (++llamadas == fallarEn) throw StateError('Fallo simulado');
    await real.preparar(
      usuarios,
      usuariosConDemostracion: usuariosConDemostracion,
    );
  }
}

/// Reproduce el JSON escrito antes de existir la carga de ejemplos por cuenta.
Future<void> _simularCuentasAntiguas(AlmacenLocal almacen) async {
  final cuentas =
      jsonDecode(almacen.leerTexto(RepositorioUsuarios.claveUsuarios)!) as List;
  for (final cuenta in cuentas) {
    (cuenta as Map).remove('incluirPerfilesDemostracion');
  }
  await almacen.guardarTexto(
    RepositorioUsuarios.claveUsuarios,
    jsonEncode(cuentas),
  );
}

class _UsuariosConFalloSesion extends RepositorioUsuarios {
  _UsuariosConFalloSesion(super.almacen);
  bool fallar = true;
  bool fallarBorrado = false;

  @override
  Future<void> guardarSesion(String idUsuario) async {
    if (fallar) {
      fallar = false;
      throw StateError('Fallo simulado al guardar sesión');
    }
    await super.guardarSesion(idUsuario);
  }

  @override
  Future<void> borrarSesion() async {
    if (fallarBorrado) {
      fallarBorrado = false;
      throw StateError('Fallo simulado al borrar sesión');
    }
    await super.borrarSesion();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  for (final sqlite in [false, true]) {
    group('propiedad (${sqlite ? 'SQLite' : 'memoria'})', () {
      late RepositorioPerfiles a;
      late RepositorioPerfiles b;
      Database? bd;

      setUp(() async {
        if (sqlite) {
          bd = await BdLocal.abrir(
            fabrica: databaseFactoryFfi,
            ruta: inMemoryDatabasePath,
          );
          a = RepositorioPerfilesSqlite(
            bd!,
            usuarioId: 'a',
            gruposValidos: _grupos,
          );
          b = RepositorioPerfilesSqlite(
            bd!,
            usuarioId: 'b',
            gruposValidos: _grupos,
          );
        } else {
          final almacen = AlmacenPerfilesMemoria();
          a = RepositorioPerfilesMemoria(
            usuarioId: 'a',
            gruposValidos: _grupos,
            almacen: almacen,
          );
          b = RepositorioPerfilesMemoria(
            usuarioId: 'b',
            gruposValidos: _grupos,
            almacen: almacen,
          );
        }
      });
      tearDown(() async => bd?.close());

      test(
        'personal único, vacío e inactivo aun con llamadas concurrentes',
        () async {
          final creados = await Future.wait(
            List.generate(5, (_) => a.asegurarPersonal()),
          );
          expect(creados.map((p) => p.id).toSet(), hasLength(1));
          final personal = (await a.obtenerTodos()).single;
          expect(personal.usuarioId, 'a');
          expect(personal.esPersonal, isTrue);
          expect(personal.nombre, 'Mi perfil');
          expect(personal.restricciones, isEmpty);
          expect(await a.obtenerActivos(), isEmpty);
          expect(await b.obtenerPersonal(), isNull);
        },
      );

      test(
        'el personal se edita, pero no se elimina ni cambia su identidad',
        () async {
          final personal = await a.asegurarPersonal();
          await a.actualizar(personal.copiarCon(restricciones: _restricciones));
          await a.marcarActivos({personal.id});
          await a.asegurarPersonal();
          expect(
            (await a.obtenerPersonal())!.restricciones.map((r) => r.severidad),
            Severidad.values.reversed,
          );
          expect((await a.obtenerActivos()).single.id, personal.id);
          await expectLater(
            a.eliminar(personal.id),
            throwsA(isA<PerfilProtegido>()),
          );
          await expectLater(
            a.actualizar(personal.copiarCon(usuarioId: 'b')),
            throwsA(isA<PerfilProtegido>()),
          );
          await expectLater(
            a.actualizar(personal.copiarCon(esPersonal: false)),
            throwsA(isA<PerfilProtegido>()),
          );
          expect((await a.obtenerPersonal())!.id, personal.id);
        },
      );

      test(
        'lectura, edición, borrado y selección rechazan perfiles ajenos',
        () async {
          final propio = await a.crear(
            const Perfil(nombre: 'A', restricciones: []),
          );
          final ajeno = await b.crear(
            const Perfil(nombre: 'B', restricciones: _restricciones),
          );
          await a.marcarActivos({propio.id});
          await b.marcarActivos({ajeno.id});
          expect((await a.obtenerTodos()).single.id, propio.id);
          expect((await b.obtenerTodos()).single.id, ajeno.id);
          await expectLater(
            a.actualizar(ajeno.copiarCon(nombre: 'intruso')),
            throwsA(isA<PerfilNoEncontrado>()),
          );
          await expectLater(
            a.eliminar(ajeno.id),
            throwsA(isA<PerfilNoEncontrado>()),
          );
          await expectLater(
            a.marcarActivos({ajeno.id}),
            throwsA(isA<PerfilNoEncontrado>()),
          );
          expect((await a.obtenerActivos()).single.id, propio.id);
          await a.marcarActivos({});
          expect((await b.obtenerActivos()).single.id, ajeno.id);
          expect((await b.obtenerTodos()).single.restricciones, hasLength(3));
        },
      );

      test(
        'no se puede crear un segundo personal ni falsificar el propietario',
        () async {
          await a.asegurarPersonal();
          await expectLater(
            a.crear(
              const Perfil(nombre: 'otro', restricciones: [], esPersonal: true),
            ),
            throwsA(isA<PerfilProtegido>()),
          );
          await expectLater(
            a.crear(
              const Perfil(nombre: 'otro', restricciones: [], usuarioId: 'b'),
            ),
            throwsA(isA<PerfilProtegido>()),
          );
          final adicional = await a.crear(
            const Perfil(nombre: 'adicional', restricciones: []),
          );
          await expectLater(
            a.actualizar(adicional.copiarCon(usuarioId: 'b')),
            throwsA(isA<PerfilProtegido>()),
          );
        },
      );
    });
  }

  group('migración v1 → v2', () {
    late Directory temporal;
    late String ruta;
    late List<Map<String, Object?>> restricciones;
    late List<Map<String, Object?>> activos;

    setUp(() async {
      temporal = Directory.systemTemp.createTempSync('safelabel_migracion_');
      ruta = p.join(temporal.path, 'v1.db');
      final v1 = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE perfil (
            id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL)''');
            await db.execute('''CREATE TABLE restriccion_perfil (
            perfil_id INTEGER NOT NULL REFERENCES perfil(id) ON DELETE CASCADE,
            grupo_alergeno_id TEXT NOT NULL, severidad TEXT NOT NULL
            CHECK (severidad IN ('leve', 'moderada', 'anafilaxia')),
            PRIMARY KEY (perfil_id, grupo_alergeno_id))''');
            await db.execute(
              '''CREATE TABLE perfil_activo (
            perfil_id INTEGER PRIMARY KEY REFERENCES perfil(id) ON DELETE CASCADE)''',
            );
            await db.insert('perfil', {'id': 7, 'nombre': 'Familiar'});
            await db.insert('perfil', {'id': 12, 'nombre': 'Otro perfil'});
            for (final r in _restricciones) {
              await db.insert('restriccion_perfil', {
                'perfil_id': 7,
                'grupo_alergeno_id': r.grupoAlergenoId,
                'severidad': r.severidad.name,
              });
            }
            await db.insert('perfil_activo', {'perfil_id': 7});
            // Una tabla ajena a perfiles debe quedar completamente intacta.
            await db.execute(
              'CREATE TABLE ingrediente (id TEXT PRIMARY KEY, fuente TEXT)',
            );
            await db.insert('ingrediente', {
              'id': 'testigo',
              'fuente': 'curada',
            });
          },
        ),
      );
      restricciones = await v1.query('restriccion_perfil');
      activos = await v1.query('perfil_activo');
      await v1.close();
    });
    tearDown(() => temporal.deleteSync(recursive: true));

    Future<Database> abrir() =>
        BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    RepositorioPerfilesSqlite repo(Database db, String usuario) =>
        RepositorioPerfilesSqlite(
          db,
          usuarioId: usuario,
          gruposValidos: _grupos,
        );

    test(
      'un fallo del upgrade revierte el esquema y permite volver a abrir',
      () async {
        var db = await databaseFactoryFfi.openDatabase(ruta);
        await db.execute('CREATE INDEX perfil_usuario ON ingrediente(id)');
        await db.close();
        await expectLater(abrir(), throwsA(isA<DatabaseException>()));
        db = await databaseFactoryFfi.openDatabase(ruta);
        expect(await db.getVersion(), 1);
        final columnas = await db.rawQuery('PRAGMA table_info(perfil)');
        expect(columnas.map((c) => c['name']), ['id', 'nombre']);
        expect(await db.query('restriccion_perfil'), restricciones);
        expect(await db.query('perfil_activo'), activos);
        await db.execute('DROP INDEX perfil_usuario');
        await db.close();
        db = await abrir();
        await PreparadorPerfilesSqlite(db).preparar({'a'});
        expect(await db.getVersion(), 2);
        expect(await repo(db, 'a').obtenerTodos(), hasLength(3));
        await db.close();
      },
    );

    test('una cuenta recibe los adicionales sin alterar restricciones ni selección', () async {
      var db = await abrir();
      expect(await db.getVersion(), 2);
      await PreparadorPerfilesSqlite(db).preparar({'a'});
      final personal = (await repo(db, 'a').obtenerPersonal())!;
      final todos = await repo(db, 'a').obtenerTodos();
      expect(todos.map((p) => p.nombre), [
        'Familiar',
        'Otro perfil',
        'Mi perfil',
      ]);
      expect(todos.where((p) => !p.esPersonal).map((p) => p.id), ['7', '12']);
      expect(personal.restricciones, isEmpty);
      expect((await repo(db, 'a').obtenerActivos()).single.id, '7');
      expect(await db.query('restriccion_perfil'), restricciones);
      expect(await db.query('perfil_activo'), activos);
      expect(await db.query('ingrediente'), [
        {'id': 'testigo', 'fuente': 'curada'},
      ]);
      await db.close();
      db = await abrir();
      await PreparadorPerfilesSqlite(db).preparar({'a', 'b'});
      expect((await repo(db, 'a').obtenerPersonal())!.id, personal.id);
      expect(await repo(db, 'b').obtenerTodos(), hasLength(1));
      expect(await db.query('restriccion_perfil'), restricciones);
      expect(await db.query('perfil_activo'), activos);
      await db.close();
    });

    for (final iniciales in [
      <String>{},
      {'a', 'b'},
    ]) {
      test(
        '${iniciales.length} cuentas: heredados pendientes no se apropian después',
        () async {
          final db = await abrir();
          addTearDown(db.close);
          final preparador = PreparadorPerfilesSqlite(db);
          await preparador.preparar(iniciales);
          await preparador.preparar({'a'});
          final pendientes = await db.query(
            'perfil',
            where: 'usuario_id IS NULL',
          );
          expect(pendientes.map((p) => p['id']), [7, 12]);
          expect(
            (await repo(db, 'a').obtenerTodos()).every((p) => p.esPersonal),
            isTrue,
          );
          expect(await repo(db, 'a').obtenerActivos(), isEmpty);
          expect(await db.query('restriccion_perfil'), restricciones);
          expect(await db.query('perfil_activo'), activos);
        },
      );
    }

    test(
      'fallo intermedio revierte la asignación, el marcador y los personales',
      () async {
        final db = await abrir();
        addTearDown(db.close);
        await db.execute(
          '''CREATE TRIGGER fallo_preparacion BEFORE INSERT ON perfil
        WHEN NEW.es_personal = 1
        BEGIN SELECT RAISE(ABORT, 'fallo simulado'); END''',
        );
        final preparador = PreparadorPerfilesSqlite(db);
        await expectLater(
          preparador.preparar({'a'}),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db.query('migracion_perfiles'), isEmpty);
        expect(
          await db.query('perfil', where: 'usuario_id IS NULL'),
          hasLength(2),
        );
        expect(await db.query('restriccion_perfil'), restricciones);
        expect(await db.query('perfil_activo'), activos);
        await db.execute('DROP TRIGGER fallo_preparacion');
        await preparador.preparar({'a'});
        await preparador.preparar({'a'});
        expect(await repo(db, 'a').obtenerTodos(), hasLength(3));
        expect(await db.query('migracion_perfiles'), hasLength(1));
      },
    );

    test(
      'SQLite protege personal y propiedad aun sin pasar por el repositorio',
      () async {
        final db = await abrir();
        addTearDown(db.close);
        await PreparadorPerfilesSqlite(db).preparar({'a'});
        final personal = (await repo(db, 'a').obtenerPersonal())!;
        for (final sql in [
          'DELETE FROM perfil WHERE id = ${personal.id}',
          "UPDATE perfil SET usuario_id = 'b' WHERE id = ${personal.id}",
          'UPDATE perfil SET es_personal = 0 WHERE id = ${personal.id}',
          "UPDATE perfil SET usuario_id = 'b' WHERE id = 7",
          "INSERT INTO perfil(nombre, usuario_id, es_personal) VALUES('otro', 'a', 1)",
          "INSERT INTO perfil(nombre, es_personal) VALUES('huérfano', 1)",
        ]) {
          await expectLater(db.execute(sql), throwsA(isA<DatabaseException>()));
        }
        expect(await db.query('restriccion_perfil'), restricciones);
        expect(await db.query('perfil_activo'), activos);
      },
    );

    test('registrar una segunda cuenta no cambia la asignación de la única antigua', () async {
      SharedPreferences.setMockInitialValues({});
      final almacen = await AlmacenLocal.abrir();
      final usuarios = RepositorioUsuarios(almacen);
      final antiguo = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesMemoria(),
      );
      final a = await _registrar(antiguo, 'a@mail.com');
      await _simularCuentasAntiguas(almacen);
      final db = await abrir();
      addTearDown(db.close);
      final nuevo = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesSqlite(db),
      );
      final b = await _registrar(nuevo, 'b@mail.com');
      expect((await repo(db, a.id).obtenerTodos()).map((p) => p.nombre), [
        'Familiar',
        'Otro perfil',
        'Mi perfil',
      ]);
      final perfilesB = await repo(db, b.id).obtenerTodos();
      expect(perfilesB, hasLength(5));
      expect(perfilesB.where((p) => p.esPersonal), hasLength(1));
      expect((await repo(db, a.id).obtenerActivos()).single.id, '7');
    });

    test('restaurar migra todas las cuentas de SharedPreferences, no solo la sesión', () async {
      SharedPreferences.setMockInitialValues({});
      final almacen = await AlmacenLocal.abrir();
      final usuarios = RepositorioUsuarios(almacen);
      final antiguo = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesMemoria(),
      );
      final a = await _registrar(antiguo, 'a@mail.com');
      final b = await _registrar(antiguo, 'b@mail.com');
      await _simularCuentasAntiguas(almacen);
      final cuentasAntes = almacen.leerTexto(RepositorioUsuarios.claveUsuarios);
      final db = await abrir();
      addTearDown(db.close);
      final nuevo = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesSqlite(db),
      );
      await nuevo.restaurarSesion();
      expect(nuevo.cuentaActual()!.id, b.id);
      expect((await repo(db, a.id).obtenerTodos()).single.esPersonal, isTrue);
      expect((await repo(db, b.id).obtenerTodos()).single.esPersonal, isTrue);
      expect(
        await db.query('perfil', where: 'usuario_id IS NULL'),
        hasLength(2),
      );
      expect(
        almacen.leerTexto(RepositorioUsuarios.claveUsuarios),
        cuentasAntes,
      );
      expect(await db.query('restriccion_perfil'), restricciones);
      expect(await db.query('perfil_activo'), activos);
    });
  });

  group('cuentas y recuperación entre almacenamientos', () {
    late Database db;
    late RepositorioUsuarios usuarios;
    late AlmacenLocal almacen;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      almacen = await AlmacenLocal.abrir();
      usuarios = RepositorioUsuarios(almacen);
      db = await BdLocal.abrir(
        fabrica: databaseFactoryFfi,
        ruta: inMemoryDatabasePath,
      );
    });
    tearDown(() async => db.close());

    RepositorioPerfilesSqlite perfiles(String id) =>
        RepositorioPerfilesSqlite(db, usuarioId: id, gruposValidos: _grupos);

    test('altas concurrentes conservan ambas cuentas y un cierre posterior gana al login', () async {
      final servicio = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesSqlite(db),
      );
      final creadas = await Future.wait([
        _registrar(servicio, 'a@mail.com'),
        _registrar(servicio, 'b@mail.com'),
      ]);
      expect(usuarios.obtenerTodos(), hasLength(2));
      for (final cuenta in creadas) {
        expect(await perfiles(cuenta.id).obtenerTodos(), hasLength(5));
      }
      final login = servicio.iniciarSesion(
        email: 'a@mail.com',
        contrasena: 'secreta123',
      );
      final cierre = servicio.cerrarSesion();
      await login;
      await cierre;
      expect(servicio.haySesionActiva, isFalse);
      expect(usuarios.leerSesion(), isNull);
    });

    test('fallo al cerrar conserva el acceso hasta que el cierre se pueda persistir', () async {
      final repo = _UsuariosConFalloSesion(almacen)..fallar = false;
      final servicio = ServicioCuenta(
        repo,
        preparador: PreparadorPerfilesSqlite(db),
      );
      final cuenta = await _registrar(servicio, 'a@mail.com');
      repo.fallarBorrado = true;
      await expectLater(servicio.cerrarSesion(), throwsA(isA<ErrorCuenta>()));
      expect(servicio.cuentaActual()!.id, cuenta.id);
      await servicio.cerrarSesion();
      expect(servicio.haySesionActiva, isFalse);
      expect(repo.leerSesion(), isNull);
      expect(await perfiles(cuenta.id).obtenerTodos(), hasLength(5));
    });

    test('registro, cambio de cuenta, restauración y cierre conservan los datos propios', () async {
      final servicio = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesSqlite(db),
      );
      await servicio.restaurarSesion();
      final a = await _registrar(servicio, 'a@mail.com');
      final personalA = (await perfiles(a.id).obtenerPersonal())!;
      expect(personalA.restricciones, isEmpty);
      expect(
        (await perfiles(a.id).obtenerActivos()).any((p) => p.esPersonal),
        isFalse,
      );
      await perfiles(a.id)
          .actualizar(personalA.copiarCon(restricciones: _restricciones));
      await perfiles(a.id).marcarActivos({personalA.id});
      await servicio.cerrarSesion();
      final b = await _registrar(servicio, 'b@mail.com');
      expect(await perfiles(b.id).obtenerTodos(), hasLength(5));
      expect(
        (await perfiles(b.id).obtenerActivos()).any((p) => p.esPersonal),
        isFalse,
      );
      await servicio.cerrarSesion();
      await servicio.iniciarSesion(
        email: 'a@mail.com',
        contrasena: 'secreta123',
      );
      final reabierto = ServicioCuenta(
        RepositorioUsuarios(await AlmacenLocal.abrir()),
        preparador: PreparadorPerfilesSqlite(db),
      );
      expect(reabierto.haySesionActiva, isFalse);
      await reabierto.restaurarSesion();
      expect(reabierto.cuentaActual()!.id, a.id);
      expect((await perfiles(a.id).obtenerPersonal())!.id, personalA.id);
      expect(
        (await perfiles(a.id).obtenerActivos()).single.restricciones,
        hasLength(3),
      );
      await reabierto.cerrarSesion();
      expect(usuarios.leerSesion(), isNull);
      expect(await perfiles(a.id).obtenerTodos(), hasLength(5));
    });

    test('cuenta guardada sin perfil se recupera al iniciar sesión sin duplicar usuario', () async {
      final servicio = ServicioCuenta(
        usuarios,
        preparador: _PreparadorConFallo(
          PreparadorPerfilesSqlite(db),
          fallarEn: 2,
        ),
      );
      await expectLater(
        _registrar(servicio, 'a@mail.com'),
        throwsA(isA<ErrorCuenta>()),
      );
      expect(usuarios.obtenerTodos(), hasLength(1));
      expect(usuarios.leerSesion(), isNull);
      expect(servicio.haySesionActiva, isFalse);
      final id = usuarios.obtenerTodos().single.id;
      expect(await perfiles(id).obtenerPersonal(), isNull);
      final nuevo = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesSqlite(db),
      );
      await nuevo.iniciarSesion(email: 'a@mail.com', contrasena: 'secreta123');
      expect(nuevo.cuentaActual()!.id, id);
      expect(await perfiles(id).obtenerTodos(), hasLength(5));
      expect(usuarios.obtenerTodos(), hasLength(1));
    });

    test(
      'fallo al guardar sesión conserva el personal y permite reintentar',
      () async {
        final repo = _UsuariosConFalloSesion(almacen);
        final servicio = ServicioCuenta(
          repo,
          preparador: PreparadorPerfilesSqlite(db),
        );
        await expectLater(
          _registrar(servicio, 'a@mail.com'),
          throwsA(isA<ErrorCuenta>()),
        );
        expect(servicio.haySesionActiva, isFalse);
        final id = repo.obtenerTodos().single.id;
        final personal = (await perfiles(id).obtenerPersonal())!;
        await servicio.iniciarSesion(
          email: 'a@mail.com',
          contrasena: 'secreta123',
        );
        expect((await perfiles(id).obtenerPersonal())!.id, personal.id);
        expect(await perfiles(id).obtenerTodos(), hasLength(5));
      },
    );

    test('fallo al restaurar no habilita una sesión antigua hasta recuperar perfiles', () async {
      final servicio = ServicioCuenta(
        usuarios,
        preparador: PreparadorPerfilesSqlite(db),
      );
      final cuenta = await _registrar(servicio, 'a@mail.com');
      final nuevo = ServicioCuenta(
        usuarios,
        preparador: _PreparadorConFallo(
          PreparadorPerfilesSqlite(db),
          fallarEn: 1,
        ),
      );
      await expectLater(nuevo.restaurarSesion(), throwsA(isA<ErrorCuenta>()));
      expect(nuevo.haySesionActiva, isFalse);
      expect(usuarios.leerSesion(), cuenta.id);
      await nuevo.restaurarSesion();
      expect(nuevo.cuentaActual()!.id, cuenta.id);
      expect(await perfiles(cuenta.id).obtenerTodos(), hasLength(5));
    });
  });
}
