import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/modelo/resultado_analisis.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';

import 'ayuda_base.dart';

void main() {
  final analizador = Analizador(baseMinima());

  const perfilLeche = Perfil(
    nombre: 'Leche grave',
    restricciones: [
      RestriccionPerfil(grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
    ],
  );
  const perfilTrigo = Perfil(
    nombre: 'Celíaco',
    restricciones: [
      RestriccionPerfil(grupoAlergenoId: 'trigo', severidad: Severidad.moderada),
    ],
  );

  LecturaOcr ocr(List<(String, double)> lineas) => LecturaOcr([
        for (var i = 0; i < lineas.length; i++)
          LineaOcr(texto: lineas[i].$1, confianza: lineas[i].$2, indice: i),
      ]);

  test('bloque 1: coincidencia de ingrediente con el perfil', () {
    final r = analizador.analizar(
      ocr([('Ingredientes: caseinato de sodio, sal, azucar.', 0.95)]),
      perfilesActivos: [perfilLeche],
    );
    expect(r.coincidencias, hasLength(1));
    final h = r.coincidencias.single;
    expect(h.grupoAlergeno, 'leche');
    expect(h.perfilesAfectados, ['Leche grave']);
    expect(h.origen, OrigenHallazgo.ingrediente);
    expect(h.porQue, isNotEmpty);
    expect(h.fuente, isNotEmpty);
  });

  test('no hay bloque de aptitud: el resultado no expone veredicto', () {
    final r = analizador.analizar(
      ocr([('Ingredientes: agua, sal.', 0.95)]),
      perfilesActivos: [perfilLeche],
    );
    // Sin coincidencias, pero eso no es un "apto".
    expect(r.coincidencias, isEmpty);
    expect(r.toString().toLowerCase(), isNot(contains('apto')));
  });

  test('bloque 2: ingrediente desconocido, con conteo', () {
    final r = analizador.analizar(
      ocr([('Ingredientes: caseinato de sodio, quinotos, sal.', 0.95)]),
      perfilesActivos: [perfilLeche],
    );
    expect(r.totalItems, 3);
    expect(r.noReconocidos.map((e) => e.texto), contains('quinotos'));
    expect(r.itemsAnalizados, 2);
    expect(r.conteoAnalizados, '2 de 3 ingredientes analizados');
  });

  test('bloque 2: perfil con anafilaxia refuerza el aviso por desconocidos', () {
    final r = analizador.analizar(
      ocr([('Ingredientes: xyzcosa rara.', 0.95)]),
      perfilesActivos: [perfilLeche],
    );
    expect(r.noReconocidos.single.advertenciaReforzada, isTrue);
  });

  test('bloque 3: línea de baja confianza es no legible y se declara', () {
    final r = analizador.analizar(
      ocr([
        ('Ingredientes: caseinato de sodio, sal.', 0.95),
        ('conservante y esta', 0.20),
      ]),
      perfilesActivos: [perfilLeche],
    );
    expect(r.hayLecturaParcial, isTrue);
    expect(r.noLegibles.single.lineaIndice, 1);
  });

  test('sección 5.3 fila 1: CONTIENE cubre un hueco de la base', () {
    final r = analizador.analizar(
      ocr([
        ('Ingredientes: agua, sal, especias.', 0.95),
        ('CONTIENE: trigo.', 0.95),
      ]),
      perfilesActivos: [perfilTrigo],
    );
    final h = r.coincidencias.single;
    expect(h.grupoAlergeno, 'cereales con gluten');
    expect(h.origen, OrigenHallazgo.lineaContiene);
    // Fila 2: además queda un aviso de prioridad alta por el hueco.
    expect(r.avisosCruce.any((a) => a.prioridad == PrioridadCola.alta), isTrue);
  });

  test('sección 5.3 fila 3: ingrediente marca alérgeno que CONTIENE no declara', () {
    final r = analizador.analizar(
      ocr([
        ('Ingredientes: caseinato de sodio, harina de trigo.', 0.95),
        ('CONTIENE: trigo.', 0.95),
      ]),
      perfilesActivos: [perfilLeche, perfilTrigo],
    );
    final hLeche = r.coincidencias.firstWhere((h) => h.grupoAlergeno == 'leche');
    expect(hLeche.aclaracionCruce, isNotNull);
    final hTrigo = r.coincidencias
        .firstWhere((h) => h.grupoAlergeno == 'cereales con gluten');
    expect(hTrigo.origen, OrigenHallazgo.ambos);
    expect(hTrigo.aclaracionCruce, isNull);
  });

  test('sección 5.4: la excepción del CAA saca a la maltodextrina del bloque 1', () {
    final r = analizador.analizar(
      ocr([('Ingredientes: maltodextrina, sal.', 0.95)]),
      perfilesActivos: [perfilTrigo],
    );
    expect(r.coincidencias, isEmpty);
    expect(r.notasExcepciones, hasLength(1));
    expect(r.notasExcepciones.single.grupoAlergeno, 'cereales con gluten');
    expect(r.notasExcepciones.single.fuente, contains('235'));
  });

  test('trazabilidad: el resultado registra la versión de la base', () {
    final r = analizador.analizar(
      ocr([('Ingredientes: sal.', 0.95)]),
      perfilesActivos: [perfilLeche],
    );
    expect(r.versionBase, 'test-min');
  });

  test('regla 1.7: "PUEDE CONTENER" queda como texto, no como hallazgo', () {
    final r = analizador.analizar(
      ocr([
        ('Ingredientes: agua, sal.', 0.95),
        ('PUEDE CONTENER leche.', 0.95),
      ]),
      perfilesActivos: [perfilLeche],
    );
    expect(r.coincidencias, isEmpty);
    expect(r.declaracion.puedeContener, contains('leche'));
    expect(r.declaracion.lineasPuedeContener, isNotEmpty);
  });
}
