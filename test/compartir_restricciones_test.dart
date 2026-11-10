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

const restriccionesCompartidasDePrueba = [
  RestriccionPerfil(grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
  RestriccionPerfil(grupoAlergenoId: 'mani', severidad: Severidad.moderada),
];

void main() {
  final grupos = cargarBaseReal().grupos.keys.toSet();
  final codec = CodecRestriccionesCompartidas(grupos);
  final qr = codec.codificar(
    restriccionesCompartidasDePrueba,
    nombre: 'Ana',
    apellido: 'Pérez',
  );
  setUpAll(sqfliteFfiInit);

  Map<String, dynamic> documento() => jsonDecode(qr) as Map<String, dynamic>;

  String qrVersionAnterior() {
    final v1 = documento()
      ..remove('nombre')
      ..remove('apellido')
      ..['version'] = 1;
    return jsonEncode(v1);
  }

  group('contrato QR v2', () {
    test('incluye nombre, apellido, protocolo, grupos y severidades; DTO inmodificable', () {
      final mapa = documento();
      expect(mapa.keys.toSet(), {
        'tipo',
        'version',
        'esquema_grupos',
        'nombre',
        'apellido',
        'restricciones',
      });
      expect(mapa['nombre'], 'Ana');
      expect(mapa['apellido'], 'Pérez');
      expect(mapa['restricciones'], [
        {'grupo_alergeno_id': 'leche', 'severidad': 'anafilaxia'},
        {'grupo_alergeno_id': 'mani', 'severidad': 'moderada'},
      ]);
      final recibido = codec.decodificar(qr);
      expect(recibido.version, CodecRestriccionesCompartidas.versionActual);
      expect(recibido.nombreCompleto, 'Ana Pérez');
      expect(recibido.restricciones.map((r) => r.severidad), [
        Severidad.anafilaxia,
        Severidad.moderada,
      ]);
      expect(() => recibido.restricciones.clear(), throwsUnsupportedError);
    });

    test('admite espacios JSON y escapes válidos, no depende del orden', () {
      final texto = const JsonEncoder.withIndent('  ')
          .convert(documento())
          .replaceFirst('leche', r'\u006ceche');
      final recibido = codec.decodificar(texto);
      expect(recibido.restricciones.first.grupoAlergenoId, 'leche');
      expect(recibido.nombreCompleto, 'Ana Pérez');
    });

    test('mantiene compatibilidad con el QR v1 sin nombre', () {
      final recibido = codec.decodificar(qrVersionAnterior());
      expect(recibido.version, CodecRestriccionesCompartidas.versionAnterior);
      expect(recibido.esVersionAnterior, isTrue);
      expect(
        recibido.nombreCompleto,
        CodecRestriccionesCompartidas.nombreAnterior,
      );
      expect(recibido.restricciones.map((r) => r.grupoAlergenoId), [
        'leche',
        'mani',
      ]);
    });

    test('el QR v1 sigue rechazando campos extra, incluido un nombre', () {
      final conNombre = jsonDecode(qrVersionAnterior()) as Map<String, dynamic>
        ..['nombre'] = 'Persona';
      expect(
        () => codec.decodificar(jsonEncode(conNombre)),
        throwsA(isA<ErrorRestriccionesCompartidas>()),
      );
    });

    final invalidos = <String, Object?>{
      'otro tipo': documento()..['tipo'] = 'otro',
      'otra versión': documento()..['version'] = 3,
      'versión decimal': documento()..['version'] = 2.0,
      'esquema incompatible': documento()..['esquema_grupos'] = 'RES',
      'datos de cuenta': documento()..['email'] = 'persona@example.test',
      'propietario inyectado': documento()..['usuario_id'] = 'otro',
      'marca personal': documento()..['es_personal'] = true,
      'nombre ausente': documento()..remove('nombre'),
      'apellido ausente': documento()..remove('apellido'),
      'nombre vacío': documento()..['nombre'] = ' ',
      'apellido nulo': documento()..['apellido'] = null,
      'nombre con control': documento()..['nombre'] = 'Ana\nPérez',
      'nombre demasiado largo': documento()..['nombre'] = 'A' * 61,
      'nombre y apellido demasiado largos': documento()
        ..['nombre'] = 'A' * 31
        ..['apellido'] = 'B' * 30,
      'restricciones vacías': documento()..['restricciones'] = [],
      'restricciones nulas': documento()..['restricciones'] = null,
      'restricciones como texto': documento()..['restricciones'] = 'leche',
      'restricción no objeto': documento()..['restricciones'] = ['leche'],
      'grupo desconocido': documento()
        ..['restricciones'] = [
          {'grupo_alergeno_id': 'gluten', 'severidad': 'leve'},
        ],
      'id de otro esquema': documento()
        ..['restricciones'] = [
          {'grupo_alergeno_id': 'RES-MILK', 'severidad': 'leve'},
        ],
      'grupo repetido': documento()
        ..['restricciones'] = [
          {'grupo_alergeno_id': 'leche', 'severidad': 'anafilaxia'},
          {'grupo_alergeno_id': 'leche', 'severidad': 'leve'},
        ],
      'severidad desconocida': documento()
        ..['restricciones'] = [
          {'grupo_alergeno_id': 'leche', 'severidad': 'grave'},
        ],
      'severidad numérica': documento()
        ..['restricciones'] = [
          {'grupo_alergeno_id': 'leche', 'severidad': 1},
        ],
      'severidad ausente': documento()
        ..['restricciones'] = [
          {'grupo_alergeno_id': 'leche'},
        ],
      'campos extra en restricción': documento()
        ..['restricciones'] = [
          {
            'grupo_alergeno_id': 'leche',
            'severidad': 'leve',
            'nombre': 'persona',
          },
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
      qr.replaceFirst('"version":2', '"version":2,"version":2'),
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

    test(
      'tampoco exporta listas vacías, duplicadas o grupos no reconocidos',
      () {
        for (final lista in [
          <RestriccionPerfil>[],
          [
            restriccionesCompartidasDePrueba.first,
            restriccionesCompartidasDePrueba.first,
          ],
          [
            const RestriccionPerfil(
              grupoAlergenoId: 'otro',
              severidad: Severidad.leve,
            ),
          ],
        ]) {
          expect(
            () => codec.codificar(lista, nombre: 'Ana', apellido: 'Pérez'),
            throwsA(isA<ErrorRestriccionesCompartidas>()),
          );
        }
      },
    );

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
            restriccionesCompartidasDePrueba,
            nombre: caso.nombre,
            apellido: caso.apellido,
          ),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
      }
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

      test(
        'exporta solo Mi perfil, aunque existan otros perfiles activos',
        () async {
          final personal = await emisor.asegurarPersonal();
          await emisor.actualizar(
            personal.copiarCon(restricciones: restriccionesCompartidasDePrueba),
          );
          final adicional = await emisor.crear(
            const Perfil(
              nombre: 'No exportar este nombre',
              restricciones: [
                RestriccionPerfil(
                  grupoAlergenoId: 'trigo',
                  severidad: Severidad.leve,
                ),
              ],
            ),
          );
          await emisor.marcarActivos({adicional.id});
          final texto = await servicioEmisor.generarQrPersonal();
          expect(texto, qr);
          expect(texto, contains('"nombre":"Ana"'));
          expect(texto, contains('"apellido":"Pérez"'));
          expect(texto, isNot(contains(adicional.nombre)));
          expect(texto, isNot(contains('usuario_id')));
          expect(texto, isNot(contains('es_personal')));
          expect(
            servicioEmisor
                .leerQr(texto)
                .restricciones
                .map((r) => r.grupoAlergenoId),
            ['leche', 'mani'],
          );
        },
      );

      test(
        'el QR generado incluye el nombre real y el receptor lo conserva',
        () async {
          final personal = await emisor.asegurarPersonal();
          await emisor.actualizar(
            personal.copiarCon(restricciones: restriccionesCompartidasDePrueba),
          );
          final texto = await servicioEmisor.generarQrPersonal();
          final mapa = jsonDecode(texto) as Map<String, dynamic>;
          expect(mapa['version'], CodecRestriccionesCompartidas.versionActual);
          expect(mapa['nombre'], 'Ana');
          expect(mapa['apellido'], 'Pérez');
          expect(servicioReceptor.leerQr(texto).nombreCompleto, 'Ana Pérez');
          final copia = await servicioReceptor.guardarCopia(texto);
          expect(copia.nombre, 'Ana Pérez');
          expect((await receptor.obtenerTodos()).single.nombre, 'Ana Pérez');
        },
      );

      test(
        'no exporta un adicional en ausencia de personal ni comparte uno vacío',
        () async {
          await emisor.crear(
            const Perfil(
              nombre: 'Adicional',
              restricciones: restriccionesCompartidasDePrueba,
            ),
          );
          await expectLater(
            servicioEmisor.generarQrPersonal(),
            throwsA(isA<ErrorRestriccionesCompartidas>()),
          );
          await emisor.asegurarPersonal();
          await expectLater(
            servicioEmisor.generarQrPersonal(),
            throwsA(isA<ErrorRestriccionesCompartidas>()),
          );
        },
      );

      test('la copia pertenece al receptor, queda inactiva y no cambia su personal ni los activos', () async {
        final personal = await receptor.asegurarPersonal();
        await receptor.actualizar(
          personal.copiarCon(restricciones: restriccionesCompartidasDePrueba),
        );
        await receptor.marcarActivos({personal.id});
        final guardado = await servicioReceptor.guardarCopia(qr);
        expect(guardado.nombre, 'Ana Pérez');
        expect(guardado.usuarioId, 'receptor');
        expect(guardado.esPersonal, isFalse);
        expect(guardado.id, isNot(personal.id));
        expect(guardado.restricciones.first.severidad, Severidad.anafilaxia);
        expect((await receptor.obtenerActivos()).single.id, personal.id);
        expect((await receptor.obtenerPersonal())!.restricciones, hasLength(2));
        expect(await emisor.obtenerTodos(), isEmpty);
        await expectLater(
          emisor.eliminar(guardado.id),
          throwsA(isA<PerfilNoEncontrado>()),
        );
      });

      test('validar o cancelar antes de guardar no persiste nada', () async {
        expect(await receptor.obtenerTodos(), isEmpty);
        expect(
          () => servicioReceptor.guardarCopia('{}'),
          throwsA(isA<ErrorRestriccionesCompartidas>()),
        );
        expect(await receptor.obtenerTodos(), isEmpty);
      });

      test(
        'dos personas con las mismas restricciones pueden guardarse',
        () async {
          final primero = await servicioReceptor.guardarCopia(qr);
          final inverso = codec.codificar(
            restriccionesCompartidasDePrueba.reversed.toList(),
            nombre: 'Ana',
            apellido: 'Pérez',
          );
          final copia = await servicioReceptor.guardarCopia(inverso);
          expect(copia.id, isNot(primero.id));
          expect(await receptor.obtenerTodos(), hasLength(2));
          expect(await receptor.obtenerActivos(), isEmpty);
        },
      );

      test('acepta un QR v1 y guarda la copia como Perfil recibido', () async {
        final copia = await servicioReceptor.guardarCopia(qrVersionAnterior());
        expect(copia.nombre, CodecRestriccionesCompartidas.nombreAnterior);
        expect(copia.restricciones, hasLength(2));
        expect(await receptor.obtenerTodos(), hasLength(1));
      });

      test('la operación de importación rechaza identidad inyectada y restricciones vacías', () async {
        await expectLater(
          receptor.crearAdicionalRecibido(
            const Perfil(
              nombre: 'Personal',
              esPersonal: true,
              restricciones: restriccionesCompartidasDePrueba,
            ),
          ),
          throwsA(isA<PerfilProtegido>()),
        );
        await expectLater(
          receptor.crearAdicionalRecibido(
            const Perfil(
              nombre: 'Ajeno',
              usuarioId: 'emisor',
              restricciones: restriccionesCompartidasDePrueba,
            ),
          ),
          throwsA(isA<PerfilProtegido>()),
        );
        await expectLater(
          receptor.crearAdicionalRecibido(
            const Perfil(nombre: 'Vacío', restricciones: []),
          ),
          throwsA(isA<ErrorValidacionPerfil>()),
        );
        expect(await receptor.obtenerTodos(), isEmpty);
      });
    });
  }

  test(
    'un fallo SQLite al insertar restricciones revierte la copia completa',
    () async {
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
      final personal = await repo.asegurarPersonal();
      await repo.marcarActivos({personal.id});
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
      await expectLater(
        servicio.guardarCopia(qr),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('perfil'), antes);
      expect(await db.query('restriccion_perfil'), isEmpty);
      expect((await repo.obtenerActivos()).single.id, personal.id);
    },
  );

  test(
    'un grupo heredado desconocido impide exportar, no se omite del QR',
    () async {
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
      final personal = await repo.asegurarPersonal();
      await db.insert('restriccion_perfil', {
        'perfil_id': int.parse(personal.id),
        'grupo_alergeno_id': 'grupo_heredado',
        'severidad': 'anafilaxia',
      });
      final servicio = ServicioCompartirRestricciones(
        repositorio: repo,
        gruposValidos: grupos,
        nombrePropietario: 'Ana',
        apellidoPropietario: 'Pérez',
      );
      await expectLater(
        servicio.generarQrPersonal(),
        throwsA(isA<ErrorRestriccionesCompartidas>()),
      );
      expect(
        (await repo.obtenerPersonal())!.restricciones.single.grupoAlergenoId,
        'grupo_heredado',
      );
    },
  );

  test(
    'la copia persiste tras cerrar y reabrir SQLite v2 y se puede repetir',
    () async {
      final temporal = Directory.systemTemp.createTempSync(
        'safelabel_compartir_',
      );
      addTearDown(() => temporal.deleteSync(recursive: true));
      final ruta = p.join(temporal.path, 'perfiles.db');
      var db = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
      var repo = RepositorioPerfilesSqlite(
        db,
        usuarioId: 'r',
        gruposValidos: grupos,
      );
      var servicio = ServicioCompartirRestricciones(
        repositorio: repo,
        gruposValidos: grupos,
        nombrePropietario: 'Ana',
        apellidoPropietario: 'Pérez',
      );
      final creado = await servicio.guardarCopia(qr);
      await db.close();
      db = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
      addTearDown(db.close);
      repo = RepositorioPerfilesSqlite(
        db,
        usuarioId: 'r',
        gruposValidos: grupos,
      );
      servicio = ServicioCompartirRestricciones(
        repositorio: repo,
        gruposValidos: grupos,
        nombrePropietario: 'Ana',
        apellidoPropietario: 'Pérez',
      );
      expect(await db.getVersion(), 2);
      expect((await repo.obtenerTodos()).single.id, creado.id);
      expect(await repo.obtenerActivos(), isEmpty);
      await servicio.guardarCopia(qr);
      expect(await repo.obtenerTodos(), hasLength(2));
    },
  );
}
