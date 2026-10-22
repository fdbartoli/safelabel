import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/pipeline/verificacion_cruzada.dart';

import 'ayuda_base.dart';

void main() {
  final v = VerificacionCruzada(baseMinima());

  test('lee "CONTIENE: trigo y soja" y mapea a grupos', () {
    final d = v.analizar('Ingredientes: harina.\nCONTIENE: trigo y soja.');
    expect(d.contiene, containsAll(['trigo', 'soja']));
    expect(d.puedeContener, isEmpty);
    expect(d.lineasContiene, isNotEmpty);
  });

  test(
    'mapea la enumeración de cereales al grupo trigo, sin buscar "gluten"',
    () {
      final d = v.analizar('CONTIENE trigo, avena, cebada y/o centeno.');
      expect(d.contiene, {'trigo'});
    },
  );

  test(
    'acepta "contiene gluten" como el grupo de cereales (puente explícito)',
    () {
      final d = v.analizar('Contiene gluten.');
      expect(d.contiene, {'trigo'});
    },
  );

  test('"PUEDE CONTENER" va a trazas, separado de CONTIENE (regla 1.7)', () {
    final d = v.analizar(
      'CONTIENE: soja.\nPUEDE CONTENER leche y frutas secas.',
    );
    expect(d.contiene, {'soja'});
    expect(d.puedeContener, contains('leche'));
    expect(d.lineasPuedeContener, isNotEmpty);
  });

  test('"elaborado en una línea que también procesa maní" es traza', () {
    final d = v.analizar(
      'Elaborado en una línea que también procesa maní y leche.',
    );
    expect(d.lineasPuedeContener, isNotEmpty);
    expect(d.contiene, isEmpty);
  });

  test('ignora "no contiene"', () {
    final d = v.analizar('No contiene TACC.');
    expect(d.contiene, isEmpty);
  });

  test('CONTIENE pegado al final de la lista de ingredientes', () {
    final d = v.analizar('harina, sal, colorante. contiene trigo.');
    expect(d.contiene, {'trigo'});
  });

  test('sin línea de alérgenos: declaración vacía', () {
    final d = v.analizar('Ingredientes: agua, sal, azúcar.');
    expect(d.hayDeclaracion, isFalse);
  });
}
