import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/pipeline/analizador.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ocr/servicio_ocr.dart';

import 'ayuda_base.dart';

void main() {
  final base = cargarBaseReal();

  test('el dataset real carga y tiene versión y atribución', () {
    expect(base.version, isNotEmpty);
    expect(base.atribucion.toLowerCase(), contains('odbl'));
    expect(base.cantidadIngredientes, greaterThan(50));
  });

  test('cada ingrediente tiene fuente (regla 11: sin source_ref no entra)', () {
    for (final i in base.ingredientes) {
      expect(i.fuente.trim(), isNotEmpty, reason: '${i.nombreCanonico} sin fuente');
    }
  });

  test('todo grupo referido por un ingrediente existe', () {
    for (final i in base.ingredientes) {
      final g = i.grupoAlergenoId;
      if (g == null) continue;
      expect(base.grupo(g), isNotNull, reason: 'grupo inexistente: $g');
    }
  });

  test('los 9 grupos del Art. 235 séptimo están representados', () {
    const esperados = {
      'trigo', 'crustaceos', 'huevo', 'pescado', 'mani',
      'soja', 'leche', 'frutos_secos', 'sulfitos',
    };
    expect(base.grupos.keys.toSet(), containsAll(esperados));
  });

  test('el grupo de cereales se declara sin la palabra "gluten"', () {
    final trigo = base.grupo('trigo')!;
    expect(trigo.textoEtiqueta.toLowerCase(), isNot(contains('gluten')));
    expect(trigo.textoEtiqueta.toLowerCase(), contains('trigo'));
  });

  test('caso de humo: galletita con leche y trigo, perfiles cruzados', () async {
    final ocr = ServicioOcrFalso.desdeTexto(
      'Ingredientes: harina de trigo enriquecida, azucar, aceite vegetal, '
      'cacao, dulce de leche, lecitina de soja, sal, bicarbonato de sodio, '
      'esencia de vainilla.\n'
      'CONTIENE: trigo, leche y soja. PUEDE CONTENER mani.',
    );
    final resultado = Analizador(base).analizar(
      await ocr.reconocer(''),
      perfilesActivos: const [
        Perfil(nombre: 'Celíaco', restricciones: [
          RestriccionPerfil(grupoAlergenoId: 'trigo', severidad: Severidad.moderada),
        ]),
        Perfil(nombre: 'APLV', restricciones: [
          RestriccionPerfil(grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
        ]),
      ],
    );

    final grupos = resultado.coincidencias.map((h) => h.grupoAlergeno).toSet();
    expect(grupos, containsAll(['cereales con gluten', 'leche']));
    // La soja aparece por lecitina, pero ningún perfil la restringe.
    expect(grupos, isNot(contains('soja')));
    // "PUEDE CONTENER maní" no se convierte en hallazgo (regla 1.7).
    expect(resultado.declaracion.puedeContener, contains('mani'));
    expect(resultado.versionBase, base.version);
  });

  test('excepción del CAA: la maltodextrina no cae en el bloque 1 por gluten', () async {
    final ocr = ServicioOcrFalso.desdeTexto(
      'Ingredientes: maltodextrina, sal, aroma.\nCONTIENE: no contiene TACC.',
    );
    final resultado = Analizador(base).analizar(
      await ocr.reconocer(''),
      perfilesActivos: const [
        Perfil(nombre: 'Celíaco', restricciones: [
          RestriccionPerfil(grupoAlergenoId: 'trigo', severidad: Severidad.moderada),
        ]),
      ],
    );
    final porGluten = resultado.coincidencias
        .where((h) => h.grupoAlergeno == 'cereales con gluten');
    expect(porGluten, isEmpty);
    expect(resultado.notasExcepciones.map((n) => n.textoLeido),
        contains('maltodextrina'));
  });
}
