import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/datos/repositorio_conocimiento.dart';
import 'package:safelabel/modelo/consulta_conocimiento.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayuda_base.dart';

import 'dart:io';

void main() {
  Database? bd;
  late RepositorioConocimiento repositorio;

  setUpAll(() async {
    sqfliteFfiInit();

    final ruta = File('assets/knowledge/safelabel.sqlite').absolute.path;

    bd = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(readOnly: true),
    );

    repositorio = RepositorioConocimiento(bd!);
  });

  tearDownAll(() async {
    await bd?.close();
  });

  test('carga la versión y los conceptos de la SQLite', () async {
    final catalogo = await repositorio.cargarCatalogo();

    expect(catalogo.version, '0.11.0');
    expect(catalogo.conceptos, hasLength(42));
  });

  test('resuelve denominaciones y mapea la restricción al perfil', () async {
    final catalogo = await repositorio.cargarCatalogo();
    final concepto = catalogo.matchExacto('caseinato de sodio');

    expect(concepto, isNotNull);
    expect(concepto!.nombreCanonico, 'caseinato de sodio');
    expect(concepto.relaciones.single.restriccionId, 'RES-MILK');
    expect(concepto.relaciones.single.perfilId, 'leche');
    expect(concepto.relaciones.single.evidencias, isNotEmpty);
  });

  test(
    'el analizador usa el catálogo SQLite con perfiles existentes',
    () async {
      final catalogo = await repositorio.cargarCatalogo();
      final analizador = Analizador(baseMinima(), catalogo: catalogo);
      const perfil = Perfil(
        nombre: 'Leche',
        restricciones: [
          RestriccionPerfil(
            grupoAlergenoId: 'leche',
            severidad: Severidad.moderada,
          ),
        ],
      );

      final resultado = analizador.analizar(
        const LecturaOcr([
          LineaOcr(
            texto: 'Ingredientes: caseinato de sodio.',
            confianza: 0.99,
            indice: 0,
          ),
        ]),
        perfilesActivos: const [perfil],
      );

      expect(resultado.versionBase, '0.11.0');
      expect(resultado.coincidencias, hasLength(1));
      expect(resultado.coincidencias.single.nombreEnBase, 'caseinato de sodio');
      expect(resultado.coincidencias.single.grupoAlergeno, 'leche');
    },
  );

  test('distingue relacionado, reconocido y desconocido', () async {
    final relacionado = await repositorio.buscar('leche');
    final reconocido = await repositorio.buscar('sal');
    final desconocido = await repositorio.buscar('ingrediente inexistente');

    expect(relacionado.estado, EstadoConsultaConocimiento.matched);
    expect(relacionado.coincidencias.single.tieneRestriccion, isTrue);

    expect(reconocido.estado, EstadoConsultaConocimiento.recognized);
    expect(reconocido.coincidencias.single.tieneRestriccion, isFalse);
    expect(reconocido.coincidencias.single.evidencias, isEmpty);

    expect(desconocido.estado, EstadoConsultaConocimiento.unknown);
    expect(desconocido.coincidencias, isEmpty);
  });

  test('un concepto sin relación no se informa como desconocido', () async {
    final catalogo = await repositorio.cargarCatalogo();
    final analizador = Analizador(baseMinima(), catalogo: catalogo);

    final resultado = analizador.analizar(
      const LecturaOcr([
        LineaOcr(texto: 'Ingredientes: sal.', confianza: 0.99, indice: 0),
      ]),
      perfilesActivos: const [],
    );

    expect(resultado.coincidencias, isEmpty);
    expect(resultado.noReconocidos, isEmpty);
    expect(resultado.itemsAnalizados, 1);
  });

  test('resuelve términos de reconocimiento curados', () async {
    final lecheEntera = await repositorio.buscar('leche entera');
    final harina = await repositorio.buscar('harina enriquecida de trigo');
    final almendras = await repositorio.buscar('leche de almendras');
    final cacao = await repositorio.buscar('cacao');

    expect(lecheEntera.estado, EstadoConsultaConocimiento.matched);
    expect(lecheEntera.coincidencias.single.restriccion, 'Leche');

    expect(harina.estado, EstadoConsultaConocimiento.matched);
    expect(harina.coincidencias.single.restriccion, 'Enfermedad celíaca');

    expect(almendras.estado, EstadoConsultaConocimiento.recognized);
    expect(almendras.coincidencias.single.tieneRestriccion, isFalse);

    expect(cacao.estado, EstadoConsultaConocimiento.recognized);
    expect(cacao.coincidencias.single.tieneRestriccion, isFalse);
  });

  test('reconoce ingredientes comunes sin relación', () async {
    final agua = await repositorio.buscar('agua');
    final aceite = await repositorio.buscar('aceite de girasol');
    final carbonato = await repositorio.buscar('carbonato de calcio');

    for (final resultado in [agua, aceite, carbonato]) {
      expect(resultado.estado, EstadoConsultaConocimiento.recognized);
      expect(resultado.coincidencias.single.tieneRestriccion, isFalse);
    }

    expect(carbonato.coincidencias.single.concepto, 'carbonato de calcio');
  });

  group('consulta con el mismo criterio que el análisis', () {
    test('ignora tildes y mayúsculas', () async {
      for (final entrada in ['caseina', 'CASEÍNA', '  Caseína ']) {
        final r = await repositorio.buscar(entrada);
        expect(r.estado, EstadoConsultaConocimiento.matched, reason: entrada);
        final c = r.coincidencias.single;
        expect(c.restriccion, 'Leche');
        expect(c.coincidencia, TipoCoincidenciaConsulta.exacta);
      }
    });

    test('un nombre largo que contiene un término con restricción', () async {
      final r = await repositorio.buscar('Harina de trigo tipo 000');
      expect(r.estado, EstadoConsultaConocimiento.matched);
      final c = r.coincidencias.single;
      expect(c.restriccion, 'Enfermedad celíaca');
      expect(c.coincidencia, TipoCoincidenciaConsulta.contiene);
      expect(c.denominacion, 'harina de trigo');
    });

    test('un error de escritura coincide de forma aproximada', () async {
      final r = await repositorio.buscar('caselnato de sodio');
      expect(r.estado, EstadoConsultaConocimiento.matched);
      final c = r.coincidencias.single;
      expect(c.restriccion, 'Leche');
      expect(c.coincidencia, TipoCoincidenciaConsulta.aproximada);
      expect(c.similitud, inInclusiveRange(0.84, 0.99));
      expect(c.denominacion, 'caseinato de sodio');
    });

    test('se informan las evidencias de la relación', () async {
      final r = await repositorio.buscar('caseinato de sodio');
      expect(r.coincidencias.single.evidencias, isNotEmpty);
    });

    test('un término sin relación no se presenta como desconocido', () async {
      final r = await repositorio.buscar('Almendra');
      expect(r.estado, EstadoConsultaConocimiento.recognized);
      expect(r.coincidencias.single.tieneRestriccion, isFalse);
    });

    test(
      'algo que no se parece a nada es desconocido, sin sugerencia',
      () async {
        final r = await repositorio.buscar('xyzqwv');
        expect(r.estado, EstadoConsultaConocimiento.unknown);
        expect(r.encontrado, isFalse);
        expect(r.sugerencia, isNull);
      },
    );

    test('la entrada vacía es desconocida', () async {
      final r = await repositorio.buscar('   ');
      expect(r.estado, EstadoConsultaConocimiento.unknown);
      expect(r.coincidencias, isEmpty);
    });
  });
}
