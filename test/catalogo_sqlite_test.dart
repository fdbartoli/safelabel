import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/datos/repositorio_conocimiento.dart';
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

    expect(catalogo.version, '0.8.1');
    expect(catalogo.conceptos, hasLength(28));
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

      expect(resultado.versionBase, '0.8.1');
      expect(resultado.coincidencias, hasLength(1));
      expect(resultado.coincidencias.single.nombreEnBase, 'caseinato de sodio');
      expect(resultado.coincidencias.single.grupoAlergeno, 'leche');
    },
  );
}
