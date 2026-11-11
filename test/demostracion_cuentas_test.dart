import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/cuenta/servicio_cuenta.dart';
import 'package:safelabel/datos/almacen_local.dart';
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/perfiles_iniciales.dart';
import 'package:safelabel/datos/preparador_perfiles.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/datos/repositorio_usuarios.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayuda_base.dart';

List<Object> _restricciones(Perfil perfil) => [
  for (final r in perfil.restricciones) (r.grupoAlergenoId, r.severidad),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  final grupos = cargarBaseReal().grupos.keys.toSet();

  for (final sqlite in [false, true]) {
    group('ejemplos por cuenta (${sqlite ? 'SQLite' : 'memoria'})', () {
      Database? db;
      late PreparadorPerfiles preparador;
      late RepositorioPerfiles Function(String) repositorio;

      setUp(() async {
        if (sqlite) {
          db = await BdLocal.abrir(
            fabrica: databaseFactoryFfi,
            ruta: inMemoryDatabasePath,
          );
          preparador = PreparadorPerfilesSqlite(db!);
          repositorio = (id) => RepositorioPerfilesSqlite(
            db!,
            usuarioId: id,
            gruposValidos: grupos,
          );
        } else {
          final memoria = PreparadorPerfilesMemoria();
          preparador = memoria;
          repositorio = (id) => RepositorioPerfilesMemoria(
            usuarioId: id,
            gruposValidos: grupos,
            almacen: memoria.almacen,
          );
        }
      });
      tearDown(() async => db?.close());

      test('cada cuenta nueva recibe cuatro perfiles propios con las restricciones originales', () async {
        await preparador.preparar({'anterior'});
        await Future.wait(
          List.generate(
            3,
            (_) => preparador.preparar(
              {'anterior', 'a', 'b'},
              usuariosConDemostracion: {'a', 'b'},
            ),
          ),
        );
        expect(await repositorio('anterior').obtenerTodos(), isEmpty);
        expect(await repositorio('anterior').obtenerActivos(), isEmpty);
        final ids = <String>{};
        for (final usuario in ['a', 'b']) {
          final perfiles = await repositorio(usuario).obtenerTodos();
          expect(perfiles, hasLength(4));
          expect(perfiles.every((p) => p.usuarioId == usuario), isTrue);
          expect(
            perfiles.map((p) => p.nombre),
            perfilesIniciales.map((p) => p.nombre),
          );
          for (var i = 0; i < perfiles.length; i++) {
            expect(
              _restricciones(perfiles[i]),
              _restricciones(perfilesIniciales[i]),
            );
          }
          final activo = (await repositorio(usuario).obtenerActivos()).single;
          expect(activo.id, perfiles.first.id);
          for (final perfil in perfiles) {
            expect(ids.add(perfil.id), isTrue);
          }
        }
      });

      test('no repone borrados ni restaura nombres, restricciones o selección al reintentar', () async {
        await preparador.preparar({'a'}, usuariosConDemostracion: {'a'});
        final repo = repositorio('a');
        final perfiles = await repo.obtenerTodos();
        await repo.actualizar(
          perfiles.last.copiarCon(
            restricciones: perfilesIniciales[1].restricciones,
          ),
        );
        await repo.actualizar(
          perfiles.first.copiarCon(
            nombre: 'Mi ejemplo editado',
            restricciones: const [],
          ),
        );
        await repo.eliminar(perfiles[1].id);
        await repo.marcarActivos({});
        final antes = await repo.obtenerTodos();
        await preparador.preparar({'a'}, usuariosConDemostracion: {'a'});
        await preparador.preparar({'a'}, usuariosConDemostracion: {'a'});
        final despues = await repo.obtenerTodos();
        expect(despues.map((p) => p.id), antes.map((p) => p.id));
        expect(despues.map((p) => p.nombre), antes.map((p) => p.nombre));
        expect(despues.map(_restricciones), antes.map(_restricciones));
        expect(await repo.obtenerActivos(), isEmpty);
      });

      test(
        'preparar una cuenta nueva no toca perfiles ni activos de otra cuenta',
        () async {
          await preparador.preparar({'anterior'});
          final repo = repositorio('anterior');
          final familiar = await repo.crear(
            Perfil(
              nombre: 'Familiar',
              restricciones: perfilesIniciales.last.restricciones,
            ),
          );
          await repo.marcarActivos({familiar.id});
          final antes = await repo.obtenerTodos();
          await preparador.preparar(
            {'anterior', 'nueva'},
            usuariosConDemostracion: {'nueva'},
          );
          final despues = await repo.obtenerTodos();
          expect(despues.map((p) => p.id), antes.map((p) => p.id));
          expect(despues.map(_restricciones), antes.map(_restricciones));
          expect((await repo.obtenerActivos()).single.id, familiar.id);
          expect(await repositorio('nueva').obtenerTodos(), hasLength(4));
        },
      );
    });
  }

  test('un fallo a mitad de carga revierte ejemplos y marcador; reintentar conserva heredados', () async {
    final db = await BdLocal.abrir(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final heredado = await db.insert('perfil', {'nombre': 'Sin asignar'});
    await db.insert('restriccion_perfil', {
      'perfil_id': heredado,
      'grupo_alergeno_id': 'leche',
      'severidad': 'anafilaxia',
    });
    await db.insert('perfil_activo', {'perfil_id': heredado});
    final preparador = PreparadorPerfilesSqlite(db);
    await preparador.preparar({'antiguaA', 'antiguaB'});
    final perfilesAntes = await db.query('perfil');
    final restriccionesAntes = await db.query('restriccion_perfil');
    final activosAntes = await db.query('perfil_activo');
    final marcasAntes = await db.query('migracion_perfiles');
    await db.execute('''CREATE TRIGGER fallo_ejemplo BEFORE INSERT ON perfil
      WHEN NEW.usuario_id = 'nueva' AND NEW.nombre = 'Mateo (celíaco)'
      BEGIN SELECT RAISE(ABORT, 'fallo simulado'); END''');
    await expectLater(
      preparador.preparar(
        {'antiguaA', 'antiguaB', 'nueva'},
        usuariosConDemostracion: {'nueva'},
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('perfil'), perfilesAntes);
    expect(await db.query('restriccion_perfil'), restriccionesAntes);
    expect(await db.query('perfil_activo'), activosAntes);
    expect(await db.query('migracion_perfiles'), marcasAntes);
    await db.execute('DROP TRIGGER fallo_ejemplo');
    await preparador.preparar(
      {'antiguaA', 'antiguaB', 'nueva'},
      usuariosConDemostracion: {'nueva'},
    );
    final repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: 'nueva',
      gruposValidos: grupos,
    );
    expect(await repo.obtenerTodos(), hasLength(4));
    expect(
      (await db.query(
        'perfil',
        where: 'id = ?',
        whereArgs: [heredado],
      )).single['usuario_id'],
      isNull,
    );
    expect(
      await db.query(
        'restriccion_perfil',
        where: 'perfil_id = ?',
        whereArgs: [heredado],
      ),
      restriccionesAntes,
    );
    expect(
      await db.query(
        'perfil_activo',
        where: 'perfil_id = ?',
        whereArgs: [heredado],
      ),
      activosAntes,
    );
  });

  test('registro, edición de cuenta, login y reapertura no vuelven a cargar los ejemplos', () async {
    SharedPreferences.setMockInitialValues({});
    final temporal = Directory.systemTemp.createTempSync('safelabel_ejemplos_');
    addTearDown(() => temporal.deleteSync(recursive: true));
    final ruta = p.join(temporal.path, 'perfiles.db');
    final almacen = await AlmacenLocal.abrir();
    var db = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    final usuarios = RepositorioUsuarios(almacen);
    var servicio = ServicioCuenta(
      usuarios,
      preparador: PreparadorPerfilesSqlite(db),
    );
    final cuenta = await servicio.registrar(
      nombre: 'Ana',
      apellido: 'Pérez',
      email: 'ana@mail.com',
      fechaNacimiento: DateTime(1990),
      contrasena: 'secreta123',
      aceptaTerminos: true,
    );
    var repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: cuenta.id,
      gruposValidos: grupos,
    );
    final iniciales = await repo.obtenerTodos();
    expect(iniciales, hasLength(4));
    final eliminar = iniciales.first;
    await repo.eliminar(eliminar.id);
    await repo.marcarActivos({});
    await servicio.editarDatos(
      nombre: 'Ana María',
      apellido: 'Pérez',
      email: 'ana@mail.com',
      fechaNacimiento: DateTime(1990),
    );
    expect(
      usuarios.buscarPorId(cuenta.id)!.incluirPerfilesDemostracion,
      isTrue,
    );
    await servicio.cerrarSesion();
    await servicio.iniciarSesion(
      email: 'ana@mail.com',
      contrasena: 'secreta123',
    );
    final idsAntes = (await repo.obtenerTodos()).map((p) => p.id).toList();
    servicio.dispose();
    await db.close();
    db = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    addTearDown(db.close);
    servicio = ServicioCuenta(
      RepositorioUsuarios(await AlmacenLocal.abrir()),
      preparador: PreparadorPerfilesSqlite(db),
    );
    addTearDown(servicio.dispose);
    await servicio.restaurarSesion();
    expect(servicio.cuentaActual()!.id, cuenta.id);
    repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: cuenta.id,
      gruposValidos: grupos,
    );
    expect((await repo.obtenerTodos()).map((p) => p.id), idsAntes);
    expect(idsAntes, hasLength(3));
    expect(await repo.obtenerActivos(), isEmpty);
    expect(
      await db.query(
        'migracion_perfiles',
        where: 'clave = ?',
        whereArgs: ['demostracion:${cuenta.id}'],
      ),
      hasLength(1),
    );
  });
}
