import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/compartir/restricciones_compartidas.dart';
import 'package:safelabel/compartir/servicio_compartir_restricciones.dart';
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayuda_base.dart';

const leche = RestriccionPerfil(
  grupoAlergenoId: 'leche',
  severidad: Severidad.anafilaxia,
);
const mani = RestriccionPerfil(
  grupoAlergenoId: 'mani',
  severidad: Severidad.moderada,
);
const trigo = RestriccionPerfil(
  grupoAlergenoId: 'trigo',
  severidad: Severidad.leve,
);

void main() {
  final grupos = cargarBaseReal().grupos.keys.toSet();
  final codec = CodecRestriccionesCompartidas(grupos);
  final perfiles = [
    const Perfil(nombre: 'Sofía', restricciones: [leche, mani]),
    const Perfil(nombre: 'Mateo', restricciones: [trigo]),
  ];
  final qr = codec.codificar(perfiles, nombre: 'Ana', apellido: 'Pérez');
  setUpAll(sqfliteFfiInit);

  Map<String, dynamic> documento() => jsonDecode(qr) as Map<String, dynamic>;

  String qrV2() {
    final mapa = documento();
    mapa['version'] = 2;
    mapa['restricciones'] = mapa['perfiles'][0]['restricciones'];
    mapa.remove('perfiles');
    return jsonEncode(mapa);
  }

  String qrV1() {
    final mapa = documento();
    mapa['version'] = 1;
    mapa['restricciones'] = mapa['perfiles'][0]['restricciones'];
    mapa
      ..remove('perfiles')
      ..remove('nombre')
      ..remove('apellido');
    return jsonEncode(mapa);
  }

  group('contrato QR v3', () {
    test('incluye propietario y varios perfiles con sus restricciones', () {
      final mapa = documento();
      expect(mapa.keys.toSet(), {
        'tipo',
        'version',
        'esquema_grupos',
        'nombre',
        'apellido',
        'perfiles',
      });
      expect(mapa['version'], 3);
      expect(mapa['nombre'], 'Ana');
      expect(mapa['apellido'], 'Pérez');
      expect(mapa['perfiles'], [
        {
          'nombre': 'Sofía',
          'restricciones': [
            {'grupo_alergeno_id': 'leche', 'severidad': 'anafilaxia'},
            {'grupo_alergeno_id': 'mani', 'severidad': 'moderada'},
          ],
        },
        {
          'nombre': 'Mateo',
          'restricciones': [
            {'grupo_alergeno_id': 'trigo', 'severidad': 'leve'},
          ],
        },
      ]);

      final recibido = codec.decodificar(qr);
      expect(recibido.version, CodecRestriccionesCompartidas.versionActual);
      expect(recibido.nombreCompleto, 'Ana Pérez');
      expect(recibido.perfiles.map((p) => p.nombre), ['Sofía', 'Mateo']);
      expect(recibido.perfiles.first.restricciones, hasLength(2));
      expect(
        () => recibido.perfiles[0].restricciones.clear(),
        throwsUnsupportedError,
      );
    });

    test('admite perfiles sin restricciones', () {
      final texto = codec.codificar(
        [const Perfil(nombre: 'Sin restricciones', restricciones: [])],
        nombre: 'Ana',
        apellido: 'Pérez',
      );
      final recibido = codec.decodificar(texto);
      expect(recibido.perfiles.single.restricciones, isEmpty);
    });

    test('admite espacios JSON y escapes válidos, no depende del orden', () {
      final texto = const JsonEncoder.withIndent('  ')
          .convert(documento())
          .replaceFirst('leche', r'\u006ceche');
      final recibido = codec.decodificar(texto);
      expect(recibido.perfiles.first.restricciones.first.grupoAlergenoId, 'leche');
      expect(recibido.nombreCompleto, 'Ana Pérez');
    });

    test('mantiene lectura compatible con v2', () {
      final recibido = codec.decodificar(qrV2());
      expect(recibido.version, CodecRestriccionesCompartidas.versionV2);
      expect(recibido.esVersionAnterior, isTrue);
      expect(recibido.nombreCompleto, 'Ana Pérez');
      expect(recibido.perfiles.single.nombre, 'Ana Pérez');
      expect(recibido.perfiles.single.restricciones, hasLength(2));
    });

    test('mantiene lectura compatible con v1', () {
      final recibido = codec.decodificar(qrV1());
      expect(recibido.version, CodecRestriccionesCompartidas.versionAnterior);
      expect(recibido.esVersionAnterior, isTrue);
      expect(recibido.nombreCompleto, isEmpty);
      expect(
        recibido.perfiles.single.nombre,
        CodecRestriccionesCompartidas.nombreAnterior,
      );
      expect(recibido.perfiles.single.restricciones, hasLength(2));
    });

    test('v1 y v2 siguen rechazando campos extra', () {
      for (final texto in [
        (jsonDecode(qrV1()) as Map<String, dynamic>)..['nombre'] = 'Persona',
        (jsonDecode(qrV2()) as Map<String, dynamic>)..['perfiles'] = [],
      ]) {
        expect(
          () => codec.decodificar(jsonEncode(texto)),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
      }
    });

    final invalidos = <String, Object?>{
      'otro tipo': documento()..['tipo'] = 'otro',
      'otra versión': documento()..['version'] = 4,
      'versión decimal': documento()..['version'] = 3.0,
      'esquema incompatible': documento()..['esquema_grupos'] = 'RES',
      'datos de cuenta': documento()..['email'] = 'persona@example.test',
      'propietario inyectado': documento()..['usuario_id'] = 'otro',
      'nombre ausente': documento()..remove('nombre'),
      'apellido ausente': documento()..remove('apellido'),
      'nombre vacío': documento()..['nombre'] = ' ',
      'apellido nulo': documento()..['apellido'] = null,
      'nombre con control': documento()..['nombre'] = 'Ana\nPérez',
      'nombre demasiado largo': documento()..['nombre'] = 'A' * 61,
      'nombre y apellido demasiado largos': documento()
        ..['nombre'] = 'A' * 31
        ..['apellido'] = 'B' * 30,
      'perfiles ausentes': documento()..remove('perfiles'),
      'perfiles vacíos': documento()..['perfiles'] = [],
      'perfiles nulos': documento()..['perfiles'] = null,
      'perfiles como texto': documento()..['perfiles'] = 'Sofía',
      'perfil no objeto': documento()..['perfiles'] = ['Sofía'],
      'perfil sin nombre': documento()
        ..['perfiles'] = [
          {
            'restricciones': [
              {'grupo_alergeno_id': 'leche', 'severidad': 'leve'},
            ],
          },
        ],
      'nombre de perfil vacío': documento()
        ..['perfiles'] = [
          {
            'nombre': ' ',
            'restricciones': [],
          },
        ],
      'restricciones nulas': documento()
        ..['perfiles'] = [
          {'nombre': 'Sofía', 'restricciones': null},
        ],
      'restricciones como texto': documento()
        ..['perfiles'] = [
          {'nombre': 'Sofía', 'restricciones': 'leche'},
        ],
      'restricción no objeto': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': ['leche'],
          },
        ],
      'grupo desconocido': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {'grupo_alergeno_id': 'gluten', 'severidad': 'leve'},
            ],
          },
        ],
      'id de otro esquema': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {'grupo_alergeno_id': 'RES-MILK', 'severidad': 'leve'},
            ],
          },
        ],
      'grupo repetido': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {'grupo_alergeno_id': 'leche', 'severidad': 'anafilaxia'},
              {'grupo_alergeno_id': 'leche', 'severidad': 'leve'},
            ],
          },
        ],
      'severidad desconocida': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {'grupo_alergeno_id': 'leche', 'severidad': 'grave'},
            ],
          },
        ],
      'severidad numérica': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {'grupo_alergeno_id': 'leche', 'severidad': 1},
            ],
          },
        ],
      'severidad ausente': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {'grupo_alergeno_id': 'leche'},
            ],
          },
        ],
      'campos extra en restricción': documento()
        ..['perfiles'] = [
          {
            'nombre': 'Sofía',
            'restricciones': [
              {
                'grupo_alergeno_id': 'leche',
                'severidad': 'leve',
                'nombre': 'persona',
              },
            ],
          },
        ],
      'campos extra en perfil': documento()
        ..['perfiles'] = [
          {'nombre': 'Sofía', 'restricciones': [], 'usuario_id': 'otro'},
        ],
      'raíz lista': [],
      'raíz nula': null,
    };
    for (final caso in invalidos.entries) {
      test('rechaza ${caso.key}', () {
        expect(
          () => codec.decodificar(jsonEncode(caso.value)),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
      });
    }

    for (final texto in [
      '',
      'https://example.test/perfil',
      '{',
      '$qr basura',
      qr.replaceFirst('"version":3', '"version":3,"version":3'),
      qr.replaceFirst(
        '"severidad":"anafilaxia"',
        r'"severidad":"anafilaxia","severid\u0061d":"leve"',
      ),
      '{"x":[[[[]]]]}',
      'x' * (CodecRestriccionesCompartidas.limiteBytes + 1),
      'á' * (CodecRestriccionesCompartidas.limiteBytes ~/ 2 + 1),
    ]) {
      test(
        'rechaza QR malformado/duplicado o fuera de límites (${texto.length} caracteres)',
        () {
          expect(
            () => codec.decodificar(texto),
            throwsA(isA<ErrorRestriccionesCompartidas>()),
          );
        },
      );
    }

    test('no exporta listas vacías, duplicadas o grupos no reconocidos', () {
      for (final lista in [
        <Perfil>[],
        [
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
        ],
        [
          const Perfil(
            nombre: 'Otro',
            restricciones: [
              RestriccionPerfil(
                grupoAlergenoId: 'otro',
                severidad: Severidad.leve,
              ),
            ],
          ),
        ],
      ]) {
        expect(
          () => codec.codificar(lista, nombre: 'Ana', apellido: 'Pérez'),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
      }
    });

    test('no exporta un QR sin nombre y apellido válidos', () {
      for (final caso in [
        (nombre: '', apellido: 'Pérez'),
        (nombre: 'Ana', apellido: ' '),
        (nombre: 'A' * 61, apellido: 'Pérez'),
        (nombre: 'Ana', apellido: 'B' * 61),
        (nombre: 'A' * 31, apellido: 'B' * 30),
        (nombre: 'Ana\nPérez', apellido: 'Gómez'),
      ]) {
        expect(
          () => codec.codificar(
            perfiles,
            nombre: caso.nombre,
            apellido: caso.apellido,
          ),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
      }
    });

    test('informa cuando la selección supera 2048 bytes', () {
      final muchos = [
        for (var i = 0; i < 50; i++) Perfil(nombre: 'Perfil $i', restricciones: [leche, mani, trigo]),
      ];
      expect(
        () => codec.codificar(muchos, nombre: 'Ana', apellido: 'Pérez'),
        throwsA(
          isA<ErrorRestriccionesCompartidas>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('2048'),
          ),
        ),
      );
    });
  });

  for (final sqlite in [false, true]) {
    group('compartir (${sqlite ? 'SQLite' : 'memoria'})', () {
      Database? db;
      late RepositorioPerfiles emisor;
      late RepositorioPerfiles receptor;
      late ServicioCompartirRestricciones servicioEmisor;
      late ServicioCompartirRestricciones servicioReceptor;

      setUp(() async {
        if (sqlite) {
          db = await BdLocal.abrir(
            fabrica: databaseFactoryFfi,
            ruta: inMemoryDatabasePath,
          );
          emisor = RepositorioPerfilesSqlite(
            db!,
            usuarioId: 'emisor',
            gruposValidos: grupos,
          );
          receptor = RepositorioPerfilesSqlite(
            db!,
            usuarioId: 'receptor',
            gruposValidos: grupos,
          );
        } else {
          final almacen = AlmacenPerfilesMemoria();
          emisor = RepositorioPerfilesMemoria(
            usuarioId: 'emisor',
            gruposValidos: grupos,
            almacen: almacen,
          );
          receptor = RepositorioPerfilesMemoria(
            usuarioId: 'receptor',
            gruposValidos: grupos,
            almacen: almacen,
          );
        }
        servicioEmisor = ServicioCompartirRestricciones(
          repositorio: emisor,
          gruposValidos: grupos,
          nombrePropietario: 'Ana',
          apellidoPropietario: 'Pérez',
        );
        servicioReceptor = ServicioCompartirRestricciones(
          repositorio: receptor,
          gruposValidos: grupos,
          nombrePropietario: 'Beto',
          apellidoPropietario: 'Gómez',
        );
      });
      tearDown(() async => db?.close());

      test('exporta los perfiles elegidos, sin IDs ni datos de cuenta', () async {
        final propios = [
          await emisor.crear(perfiles[0]),
          await emisor.crear(perfiles[1]),
        ];
        final excluido = await emisor.crear(
          const Perfil(nombre: 'No exportar', restricciones: [trigo]),
        );
        final texto = await servicioEmisor.generarQr(propios);
        final recibido = servicioEmisor.leerQr(texto);
        expect(recibido.perfiles.map((p) => p.nombre), ['Sofía', 'Mateo']);
        expect(texto, isNot(contains(excluido.nombre)));
        expect(texto, isNot(contains('usuario_id')));
        expect(texto, isNot(contains('es_personal')));
        expect(recibido.perfiles.first.restricciones, hasLength(2));
      });

      test('el receptor importa todos en una sola operación, inactivos y con sus nombres', () async {
        final originales = [
          await emisor.crear(perfiles[0]),
          await emisor.crear(perfiles[1]),
        ];
        final texto = await servicioEmisor.generarQr(originales);
        final guardados = await servicioReceptor.guardarCopias(texto);
        expect(guardados.map((p) => p.nombre), ['Sofía', 'Mateo']);
        expect(guardados.every((p) => p.usuarioId == 'receptor'), isTrue);
        expect(await receptor.obtenerActivos(), isEmpty);
        final todos = await receptor.obtenerTodos();
        expect(todos.map((p) => p.nombre), ['Sofía', 'Mateo']);
        expect(todos.first.severidadPara('leche'), Severidad.anafilaxia);
        expect(todos.last.severidadPara('trigo'), Severidad.leve);
      });

      test('importar no modifica los perfiles ni la selección existentes', () async {
        final previo = await receptor.crear(
          const Perfil(nombre: 'Beto', restricciones: [leche]),
        );
        await receptor.marcarActivos({previo.id});
        final texto = await servicioEmisor.generarQr([
          await emisor.crear(perfiles[0]),
        ]);
        await servicioReceptor.guardarCopias(texto);
        expect((await receptor.obtenerActivos()).single.id, previo.id);
        expect(
          (await receptor.obtenerTodos())
              .firstWhere((p) => p.id == previo.id)
              .restricciones,
          hasLength(1),
        );
      });

      test('acepta perfiles sin restricciones', () async {
        final texto = await servicioEmisor.generarQr([
          await emisor.crear(
            const Perfil(nombre: 'Sin restricciones', restricciones: []),
          ),
        ]);
        final guardados = await servicioReceptor.guardarCopias(texto);
        expect(guardados.single.restricciones, isEmpty);
        expect((await receptor.obtenerTodos()).single.restricciones, isEmpty);
      });

      test('validar o cancelar antes de guardar no persiste nada', () async {
        expect(await receptor.obtenerTodos(), isEmpty);
        expect(
          () => servicioReceptor.guardarCopias('{}'),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
        expect(await receptor.obtenerTodos(), isEmpty);
      });

      test('dos importaciones iguales crean perfiles distintos', () async {
        final texto = await servicioEmisor.generarQr([
          await emisor.crear(perfiles[0]),
        ]);
        final primero = await servicioReceptor.guardarCopias(texto);
        final segundo = await servicioReceptor.guardarCopias(texto);
        expect(primero.single.id, isNot(segundo.single.id));
        expect(await receptor.obtenerTodos(), hasLength(2));
        expect(await receptor.obtenerActivos(), isEmpty);
      });

      test('acepta e importa un QR v1', () async {
        final guardados = await servicioReceptor.guardarCopias(qrV1());
        expect(
          guardados.single.nombre,
          CodecRestriccionesCompartidas.nombreAnterior,
        );
        expect(guardados.single.restricciones, hasLength(2));
        expect(await receptor.obtenerTodos(), hasLength(1));
      });

      test('acepta e importa un QR v2 con un perfil', () async {
        final guardados = await servicioReceptor.guardarCopias(qrV2());
        expect(guardados.single.nombre, 'Ana Pérez');
        expect(guardados.single.restricciones, hasLength(2));
        expect(await receptor.obtenerTodos(), hasLength(1));
      });

      test('la importación rechaza identidad inyectada', () async {
        await expectLater(
          receptor.crearRecibidos([
            const Perfil(
              nombre: 'Ajeno',
              usuarioId: 'emisor',
              restricciones: [leche],
            ),
          ]),
          throwsArgumentError,
        );
        expect(await receptor.obtenerTodos(), isEmpty);
      });
    });
  }

  test('un fallo SQLite al insertar restricciones revierte todos los perfiles', () async {
    final db = await BdLocal.abrir(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: 'r',
      gruposValidos: grupos,
    );
    final previo = await repo.crear(
      const Perfil(nombre: 'Previo', restricciones: [leche]),
    );
    await repo.marcarActivos({previo.id});
    final antes = await db.query('perfil');
    await db.execute(
      '''CREATE TRIGGER fallo_importar BEFORE INSERT ON restriccion_perfil
      WHEN NEW.grupo_alergeno_id = 'mani'
      BEGIN SELECT RAISE(ABORT, 'fallo simulado'); END''',
    );
    final servicio = ServicioCompartirRestricciones(
      repositorio: repo,
      gruposValidos: grupos,
      nombrePropietario: 'Ana',
      apellidoPropietario: 'Pérez',
    );
    final textoConMani = servicio.codec.codificar(
      [
        const Perfil(nombre: 'Con leche', restricciones: [leche]),
        const Perfil(nombre: 'Con maní', restricciones: [mani]),
      ],
      nombre: 'Ana',
      apellido: 'Pérez',
    );
    await expectLater(
      servicio.guardarCopias(textoConMani),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('perfil'), antes);
    expect((await repo.obtenerActivos()).single.id, previo.id);
    expect(await db.query('restriccion_perfil'), hasLength(1));
  });

  test('un grupo heredado desconocido impide exportar, no se omite del QR', () async {
    final db = await BdLocal.abrir(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: 'r',
      gruposValidos: grupos,
    );
    final perfil = await repo.crear(
      const Perfil(nombre: 'Heredado', restricciones: [leche]),
    );
    await db.insert('restriccion_perfil', {
      'perfil_id': int.parse(perfil.id),
      'grupo_alergeno_id': 'grupo_heredado',
      'severidad': 'anafilaxia',
    });
    final servicio = ServicioCompartirRestricciones(
      repositorio: repo,
      gruposValidos: grupos,
      nombrePropietario: 'Ana',
      apellidoPropietario: 'Pérez',
    );
    final conHeredado = (await repo.obtenerTodos()).single;
    await expectLater(
      servicio.generarQr([conHeredado]),
      throwsA(isA<ErrorRestriccionesCompartidas>()),
    );
    expect(conHeredado.restricciones, hasLength(2));
  });

  test('los perfiles importados persisten tras cerrar y reabrir SQLite', () async {
    final temporal = Directory.systemTemp.createTempSync('safelabel_compartir_');
    addTearDown(() => temporal.deleteSync(recursive: true));
    final ruta = p.join(temporal.path, 'perfiles.db');
    var db = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    var repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: 'r',
      gruposValidos: grupos,
    );
    final servicio = ServicioCompartirRestricciones(
      repositorio: repo,
      gruposValidos: grupos,
      nombrePropietario: 'Ana',
      apellidoPropietario: 'Pérez',
    );
    final creados = await servicio.guardarCopias(qr);
    await db.close();
    db = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    addTearDown(db.close);
    repo = RepositorioPerfilesSqlite(
      db,
      usuarioId: 'r',
      gruposValidos: grupos,
    );
    expect(await db.getVersion(), 3);
    expect(
      (await repo.obtenerTodos()).map((p) => p.id),
      creados.map((p) => p.id),
    );
    expect(await repo.obtenerActivos(), isEmpty);
  });
}
