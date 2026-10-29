import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safelabel/datos/bd_local.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/modelo/resultado_analisis.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayuda_base.dart';

/// Demuestra que el módulo de perfiles quedó integrado con el análisis y no
/// aislado: un perfil que pasó por el repositorio (y en SQLite, por un cierre
/// y reapertura de la base) produce exactamente los mismos hallazgos que el
/// mismo perfil armado en memoria.
void main() {
  final base = cargarBaseReal();
  final analizador = Analizador(base);
  final gruposValidos = base.grupos.keys.toSet();

  // Dos perfiles con severidades distintas: así se ve si la persistencia
  // pierde o degrada alguna (la anafilaxia refuerza el aviso por
  // desconocidos; ver analizador).
  const enMemoria = [
    Perfil(
      nombre: 'Sofía',
      restricciones: [
        RestriccionPerfil(
          grupoAlergenoId: 'leche',
          severidad: Severidad.anafilaxia,
        ),
        RestriccionPerfil(grupoAlergenoId: 'mani', severidad: Severidad.leve),
      ],
    ),
    Perfil(
      nombre: 'Mateo',
      restricciones: [
        RestriccionPerfil(
          grupoAlergenoId: 'trigo',
          severidad: Severidad.moderada,
        ),
      ],
    ),
  ];

  // Ingredientes de varios grupos, uno que no está en la base y la línea
  // CONTIENE, para ejercitar los tres caminos: coincidencia, no reconocido y
  // verificación cruzada.
  final etiqueta = LecturaOcr([
    const LineaOcr(
      texto:
          'Ingredientes: harina de trigo, suero de leche, azúcar, maní, '
          'lecitina de soja, quinotos glaseados.',
      confianza: 0.95,
      indice: 0,
    ),
    const LineaOcr(
      texto: 'CONTIENE TRIGO, LECHE, MANÍ Y SOJA.',
      confianza: 0.95,
      indice: 1,
    ),
  ]);

  /// Lo que la persona ve en los tres bloques, reducido a valores
  /// comparables. Listas anidadas y no records: un record compara sus campos
  /// con ==, y una List adentro se compararía por identidad. `expect` sí
  /// compara listas anidadas elemento por elemento.
  List<Object?> huella(ResultadoAnalisis r) => [
    r.perfilesActivos,
    r.severidadMaxima,
    [
      for (final h in r.coincidencias)
        [
          h.textoLeido,
          h.grupoAlergeno,
          h.perfilesAfectados,
          h.severidadMaxima,
          h.origen,
          h.aclaracionCruce,
        ],
    ],
    [
      for (final n in r.noReconocidos) [n.texto, n.advertenciaReforzada],
    ],
    [
      for (final a in r.avisosCruce) [a.mensaje, a.grupoAlergeno],
    ],
    r.conteoAnalizados,
  ];

  final esperado = analizador.analizar(etiqueta, perfilesActivos: enMemoria);

  test(
    'la etiqueta de prueba produce hallazgos (no es una igualdad vacía)',
    () {
      // El hallazgo trae el nombre del grupo para mostrar, no el id.
      expect(
        esperado.coincidencias.map((h) => h.grupoAlergeno).toSet(),
        containsAll([
          for (final id in ['leche', 'mani', 'trigo']) base.grupo(id)!.nombre,
        ]),
      );
      expect(esperado.noReconocidos, isNotEmpty);
      expect(esperado.noReconocidos.first.advertenciaReforzada, isTrue);
    },
  );

  test('la huella detecta una severidad degradada', () {
    // Control negativo: si la persistencia convirtiera la anafilaxia en
    // `leve`, la comparación de abajo tiene que fallar.
    final degradado = [
      enMemoria.first.copiarCon(
        restricciones: [
          for (final r in enMemoria.first.restricciones)
            RestriccionPerfil(
              grupoAlergenoId: r.grupoAlergenoId,
              severidad: Severidad.leve,
            ),
        ],
      ),
      enMemoria.last,
    ];
    final r = analizador.analizar(etiqueta, perfilesActivos: degradado);
    expect(huella(r), isNot(huella(esperado)));
  });

  Future<List<Perfil>> guardarYActivar(RepositorioPerfiles repo) async {
    final ids = <String>{};
    for (final perfil in enMemoria) {
      ids.add((await repo.crear(perfil)).id);
    }
    // Un tercer perfil inactivo no debe colarse en el análisis.
    await repo.crear(
      const Perfil(
        nombre: 'Inactivo',
        restricciones: [
          RestriccionPerfil(
            grupoAlergenoId: 'soja',
            severidad: Severidad.anafilaxia,
          ),
        ],
      ),
    );
    await repo.marcarActivos(ids);
    return repo.obtenerActivos();
  }

  test(
    'un perfil del repositorio en memoria da los mismos hallazgos',
    () async {
      final repo = RepositorioPerfilesMemoria(gruposValidos: gruposValidos);
      final activos = await guardarYActivar(repo);

      final r = analizador.analizar(etiqueta, perfilesActivos: activos);
      expect(huella(r), huella(esperado));
    },
  );

  test('un perfil guardado en SQLite, tras cerrar y reabrir, da los mismos '
      'hallazgos', () async {
    sqfliteFfiInit();
    final temporal = Directory.systemTemp.createTempSync('safelabel_');
    addTearDown(() => temporal.deleteSync(recursive: true));
    final ruta = p.join(temporal.path, BdLocal.nombreArchivo);

    var bd = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    await guardarYActivar(
      RepositorioPerfilesSqlite(bd, gruposValidos: gruposValidos),
    );
    await bd.close();

    bd = await BdLocal.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
    final activos = await RepositorioPerfilesSqlite(
      bd,
      gruposValidos: gruposValidos,
    ).obtenerActivos();
    await bd.close();

    final r = analizador.analizar(etiqueta, perfilesActivos: activos);
    expect(huella(r), huella(esperado));
  });
}
