import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayuda_base.dart';

/// Los grupos válidos salen de la base real, no de una lista escrita acá: si
/// el JSON cambia, estos tests se enteran.
final gruposValidos = cargarBaseReal().grupos.keys.toSet();

const leche = RestriccionPerfil(
  grupoAlergenoId: 'leche',
  severidad: Severidad.anafilaxia,
);
const trigo = RestriccionPerfil(
  grupoAlergenoId: 'trigo',
  severidad: Severidad.moderada,
);
const mani = RestriccionPerfil(
  grupoAlergenoId: 'mani',
  severidad: Severidad.leve,
);

/// Una implementación bajo prueba: cómo construirla y cómo liberarla.
class Implementacion {
  Implementacion(this.nombre, this.crear, {this.liberar});

  final String nombre;
  final Future<RepositorioPerfiles> Function() crear;
  final Future<void> Function()? liberar;
}

void main() {
  late DatabaseFactory fabrica;
  Database? bd;

  setUpAll(() {
    // sqflite normalmente habla con el SQLite nativo del teléfono vía plugin.
    // La variante FFI usa una librería SQLite de escritorio: así los tests
    // corren en la PC y en el servidor de CI, sin emulador.
    sqfliteFfiInit();
    fabrica = databaseFactoryFfi;
  });

  final implementaciones = [
    Implementacion(
      'memoria',
      () async => RepositorioPerfilesMemoria(gruposValidos: gruposValidos),
    ),
    Implementacion(
      'SQLite',
      () async {
        bd = await BdLocal.abrir(fabrica: fabrica, ruta: inMemoryDatabasePath);
        return RepositorioPerfilesSqlite(bd!, gruposValidos: gruposValidos);
      },
      liberar: () async {
        await bd?.close();
        bd = null;
      },
    ),
  ];

  // El mismo cuerpo de pruebas contra las dos: si ambas pasan, la de memoria
  // es un sustituto fiel de la de SQLite en otros tests.
  for (final impl in implementaciones) {
    group('contrato (${impl.nombre})', () {
      late RepositorioPerfiles repo;

      setUp(() async => repo = await impl.crear());
      tearDown(() async => impl.liberar?.call());

      group('alta', () {
        test('asigna id y conserva nombre y restricciones en orden', () async {
          final creado = await repo.crear(
            const Perfil(nombre: 'Juli', restricciones: [mani, leche]),
          );

          expect(creado.id, isNotEmpty);
          final todos = await repo.obtenerTodos();
          expect(todos, hasLength(1));
          expect(todos.single.id, creado.id);
          expect(todos.single.nombre, 'Juli');
          expect(
            todos.single.restricciones.map(
              (r) => (r.grupoAlergenoId, r.severidad),
            ),
            [('mani', Severidad.leve), ('leche', Severidad.anafilaxia)],
          );
        });

        test('obtenerTodos respeta el orden de creación', () async {
          await repo.crear(const Perfil(nombre: 'B', restricciones: [leche]));
          await repo.crear(const Perfil(nombre: 'A', restricciones: [trigo]));
          await repo.crear(const Perfil(nombre: 'C', restricciones: []));

          final nombres = (await repo.obtenerTodos()).map((p) => p.nombre);
          expect(nombres, ['B', 'A', 'C']);
        });

        test('un perfil sin restricciones también se guarda', () async {
          await repo.crear(const Perfil(nombre: 'Vacío', restricciones: []));
          final todos = await repo.obtenerTodos();
          expect(todos.single.restricciones, isEmpty);
        });

        test('recorta los espacios del nombre', () async {
          final creado = await repo.crear(
            const Perfil(nombre: '  Sofía  ', restricciones: [leche]),
          );
          expect(creado.nombre, 'Sofía');
          expect((await repo.obtenerTodos()).single.nombre, 'Sofía');
        });

        test('rechaza un perfil que ya trae id', () async {
          expect(
            () => repo.crear(
              const Perfil(id: '7', nombre: 'X', restricciones: []),
            ),
            throwsArgumentError,
          );
        });

        test('no reutiliza el id de un perfil borrado', () async {
          final a = await repo.crear(
            const Perfil(nombre: 'A', restricciones: []),
          );
          await repo.eliminar(a.id);
          final b = await repo.crear(
            const Perfil(nombre: 'B', restricciones: []),
          );
          expect(b.id, isNot(a.id));
        });

        test(
          'modificar la lista original después no cambia lo guardado',
          () async {
            final restricciones = [leche];
            await repo.crear(
              Perfil(nombre: 'Sofía', restricciones: restricciones),
            );
            restricciones.add(trigo);
            final guardado = (await repo.obtenerTodos()).single;
            expect(guardado.restricciones, hasLength(1));
          },
        );
      });

      group('edición', () {
        test('reemplaza nombre, restricciones y severidad', () async {
          final creado = await repo.crear(
            const Perfil(nombre: 'Mateo', restricciones: [trigo]),
          );

          await repo.actualizar(
            creado.copiarCon(
              nombre: 'Mateo (celíaco)',
              restricciones: const [
                RestriccionPerfil(
                  grupoAlergenoId: 'trigo',
                  severidad: Severidad.anafilaxia,
                ),
                leche,
              ],
            ),
          );

          final todos = await repo.obtenerTodos();
          expect(todos, hasLength(1));
          final p = todos.single;
          expect(p.id, creado.id);
          expect(p.nombre, 'Mateo (celíaco)');
          expect(p.severidadPara('trigo'), Severidad.anafilaxia);
          expect(p.severidadPara('leche'), Severidad.anafilaxia);
        });

        test('quitar todas las restricciones las borra', () async {
          final creado = await repo.crear(
            const Perfil(nombre: 'X', restricciones: [leche, trigo]),
          );
          await repo.actualizar(creado.copiarCon(restricciones: const []));
          expect((await repo.obtenerTodos()).single.restricciones, isEmpty);
        });

        test('editar un perfil activo lo mantiene activo', () async {
          final creado = await repo.crear(
            const Perfil(nombre: 'X', restricciones: [leche]),
          );
          await repo.marcarActivos({creado.id});
          await repo.actualizar(creado.copiarCon(restricciones: [trigo]));

          final activos = await repo.obtenerActivos();
          expect(activos.single.restringe('trigo'), isTrue);
          expect(activos.single.restringe('leche'), isFalse);
        });

        test('un perfil inexistente da PerfilNoEncontrado', () async {
          expect(
            () => repo.actualizar(
              const Perfil(id: '999', nombre: 'X', restricciones: []),
            ),
            throwsA(isA<PerfilNoEncontrado>()),
          );
        });
      });

      group('borrado', () {
        test('borra el perfil y sus restricciones', () async {
          final a = await repo.crear(
            const Perfil(nombre: 'A', restricciones: [leche, trigo]),
          );
          final b = await repo.crear(
            const Perfil(nombre: 'B', restricciones: [leche]),
          );

          await repo.eliminar(a.id);

          final todos = await repo.obtenerTodos();
          expect(todos.map((p) => p.id), [b.id]);
          // Las restricciones de B, que comparte grupo con A, siguen intactas.
          expect(todos.single.restringe('leche'), isTrue);
        });

        test('un perfil borrado deja de estar activo', () async {
          final a = await repo.crear(
            const Perfil(nombre: 'A', restricciones: [leche]),
          );
          final b = await repo.crear(
            const Perfil(nombre: 'B', restricciones: [trigo]),
          );
          await repo.marcarActivos({a.id, b.id});

          await repo.eliminar(a.id);

          expect((await repo.obtenerActivos()).map((p) => p.id), [b.id]);
        });

        test('un perfil inexistente da PerfilNoEncontrado', () async {
          expect(
            () => repo.eliminar('999'),
            throwsA(isA<PerfilNoEncontrado>()),
          );
        });
      });

      group('activos', () {
        test('devuelve los perfiles resueltos, con restricciones', () async {
          final a = await repo.crear(
            const Perfil(nombre: 'A', restricciones: [leche]),
          );
          await repo.crear(const Perfil(nombre: 'B', restricciones: [trigo]));
          final c = await repo.crear(
            const Perfil(nombre: 'C', restricciones: [mani]),
          );

          await repo.marcarActivos({c.id, a.id});

          final activos = await repo.obtenerActivos();
          // Orden de creación, no el del Set.
          expect(activos.map((p) => p.nombre), ['A', 'C']);
          expect(activos.first.severidadPara('leche'), Severidad.anafilaxia);
        });

        test('marcarActivos reemplaza la selección anterior', () async {
          final a = await repo.crear(
            const Perfil(nombre: 'A', restricciones: []),
          );
          final b = await repo.crear(
            const Perfil(nombre: 'B', restricciones: []),
          );
          await repo.marcarActivos({a.id});
          await repo.marcarActivos({b.id});
          expect((await repo.obtenerActivos()).map((p) => p.id), [b.id]);

          await repo.marcarActivos({});
          expect(await repo.obtenerActivos(), isEmpty);
        });

        test('un id inexistente falla y no toca la selección', () async {
          final a = await repo.crear(
            const Perfil(nombre: 'A', restricciones: []),
          );
          await repo.marcarActivos({a.id});

          await expectLater(
            repo.marcarActivos({a.id, '999'}),
            throwsA(isA<PerfilNoEncontrado>()),
          );
          expect((await repo.obtenerActivos()).map((p) => p.id), [a.id]);
        });
      });

      group('validaciones', () {
        Future<void> esperarRechazo(Perfil perfil) async {
          await expectLater(
            repo.crear(perfil),
            throwsA(isA<ErrorValidacionPerfil>()),
          );
          // Lo rechazado no deja nada a medio guardar.
          expect(await repo.obtenerTodos(), isEmpty);
        }

        test('nombre obligatorio', () async {
          await esperarRechazo(const Perfil(nombre: '', restricciones: []));
          await esperarRechazo(const Perfil(nombre: '   ', restricciones: []));
        });

        test('nombre de hasta 60 caracteres', () async {
          await repo.crear(Perfil(nombre: 'a' * 60, restricciones: const []));
          expect(await repo.obtenerTodos(), hasLength(1));
          await repo.eliminar((await repo.obtenerTodos()).single.id);

          await esperarRechazo(
            Perfil(nombre: 'a' * 61, restricciones: const []),
          );
        });

        test('el límite cuenta caracteres, no unidades UTF-16', () async {
          // 59 letras + un emoji (2 unidades UTF-16) = 60 caracteres.
          final nombre = '${'a' * 59}🥛';
          expect(nombre.length, 61);
          await repo.crear(Perfil(nombre: nombre, restricciones: const []));
          expect((await repo.obtenerTodos()).single.nombre, nombre);
        });

        test('sin grupos repetidos en el mismo perfil', () async {
          await esperarRechazo(
            const Perfil(
              nombre: 'Doble',
              restricciones: [
                leche,
                RestriccionPerfil(
                  grupoAlergenoId: 'leche',
                  severidad: Severidad.leve,
                ),
              ],
            ),
          );
        });

        test('el grupo tiene que existir en la base de conocimiento', () async {
          // "lactosa" no es un grupo: el grupo es "leche". Si se aceptara, el
          // análisis no cruzaría nada con este perfil.
          await esperarRechazo(
            const Perfil(
              nombre: 'Intolerante',
              restricciones: [
                RestriccionPerfil(
                  grupoAlergenoId: 'lactosa',
                  severidad: Severidad.moderada,
                ),
              ],
            ),
          );
        });

        test('las validaciones también aplican al editar', () async {
          final creado = await repo.crear(
            const Perfil(nombre: 'Sofía', restricciones: [leche]),
          );

          for (final invalido in [
            creado.copiarCon(nombre: ' '),
            creado.copiarCon(nombre: 'a' * 61),
            creado.copiarCon(restricciones: const [leche, leche]),
            creado.copiarCon(
              restricciones: const [
                RestriccionPerfil(
                  grupoAlergenoId: 'gluten',
                  severidad: Severidad.anafilaxia,
                ),
              ],
            ),
          ]) {
            await expectLater(
              repo.actualizar(invalido),
              throwsA(isA<ErrorValidacionPerfil>()),
            );
          }

          // Nada cambió.
          final p = (await repo.obtenerTodos()).single;
          expect(p.nombre, 'Sofía');
          expect(p.restricciones.single.grupoAlergenoId, 'leche');
        });
      });
    });
  }

  // Lo que solo tiene sentido para SQLite: el archivo y el esquema.
  group('SQLite', () {
    late Directory temporal;

    setUp(() => temporal = Directory.systemTemp.createTempSync('safelabel_'));
    tearDown(() => temporal.deleteSync(recursive: true));

    test('lo guardado sobrevive a cerrar y reabrir la base', () async {
      // Acá no sirve una base en memoria: desaparece al cerrarla. Se usa un
      // archivo real en un directorio temporal.
      final ruta = p.join(temporal.path, BdLocal.nombreArchivo);

      var bd = await BdLocal.abrir(fabrica: fabrica, ruta: ruta);
      var repo = RepositorioPerfilesSqlite(bd, gruposValidos: gruposValidos);
      final sofia = await repo.crear(
        const Perfil(nombre: 'Sofía', restricciones: [leche, mani]),
      );
      await repo.crear(const Perfil(nombre: 'Mateo', restricciones: [trigo]));
      await repo.marcarActivos({sofia.id});
      await bd.close();

      bd = await BdLocal.abrir(fabrica: fabrica, ruta: ruta);
      repo = RepositorioPerfilesSqlite(bd, gruposValidos: gruposValidos);
      final todos = await repo.obtenerTodos();
      final activos = await repo.obtenerActivos();
      await bd.close();

      expect(todos.map((p) => p.nombre), ['Sofía', 'Mateo']);
      expect(activos.single.id, sofia.id);
      expect(activos.single.severidadPara('leche'), Severidad.anafilaxia);
      expect(activos.single.severidadPara('mani'), Severidad.leve);
    });

    test('el borrado en cascada limpia las tablas hijas', () async {
      // El test de contrato mira la interfaz; este mira las filas. Si faltara
      // PRAGMA foreign_keys = ON, la interfaz podría verse bien y dejar filas
      // huérfanas en restriccion_perfil.
      final bd = await BdLocal.abrir(
        fabrica: fabrica,
        ruta: inMemoryDatabasePath,
      );
      final repo = RepositorioPerfilesSqlite(bd, gruposValidos: gruposValidos);
      final a = await repo.crear(
        const Perfil(nombre: 'A', restricciones: [leche, trigo]),
      );
      await repo.marcarActivos({a.id});

      await repo.eliminar(a.id);

      final restricciones = await bd.query('restriccion_perfil');
      final activos = await bd.query('perfil_activo');
      await bd.close();
      expect(restricciones, isEmpty);
      expect(activos, isEmpty);
    });

    test('el esquema rechaza una severidad desconocida', () async {
      final bd = await BdLocal.abrir(
        fabrica: fabrica,
        ruta: inMemoryDatabasePath,
      );
      final id = await bd.insert('perfil', {'nombre': 'X'});
      await expectLater(
        bd.insert('restriccion_perfil', {
          'perfil_id': id,
          'grupo_alergeno_id': 'leche',
          'severidad': 'grave',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await bd.close();
    });
  });
}
