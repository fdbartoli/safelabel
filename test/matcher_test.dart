import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/pipeline/matcher.dart';
import 'package:safelabel/pipeline/normalizador.dart';

import 'ayuda_base.dart';

void main() {
  final base = baseMinima();
  final matcher = Emparejador(base);
  const n = Normalizador();

  ItemNormalizado item(String texto) => n.separarIngredientes(texto).single;

  test('match exacto por nombre canónico', () {
    final r = matcher.match(item('caseinato de sodio'));
    expect(r, isA<Coincidencia>());
    r as Coincidencia;
    expect(r.exacta, isTrue);
    expect(r.similitud, 1.0);
    expect(r.ingrediente.grupoAlergenoId, 'leche');
  });

  test('match exacto por sinónimo', () {
    final r = matcher.match(item('caseinato sodico'));
    expect(r, isA<Coincidencia>());
    expect(
      (r as Coincidencia).ingrediente.nombreCanonico,
      'caseinato de sodio',
    );
  });

  test('match exacto por número INS', () {
    final r = matcher.match(item('INS 322'));
    expect((r as Coincidencia).ingrediente.nombreCanonico, 'lecitina de soja');
  });

  test('match difuso ante typo de OCR', () {
    // "caselnato de sodlo" es la lectura errónea típica.
    final r = matcher.match(item('caselnato de sodlo'));
    expect(r, isA<Coincidencia>());
    r as Coincidencia;
    expect(r.exacta, isFalse);
    expect(r.similitud, greaterThan(0.84));
    expect(r.ingrediente.nombreCanonico, 'caseinato de sodio');
  });

  test('desconocido que se parece a algo: probable error de OCR', () {
    final r = matcher.match(item('harian de trlgo'));
    final tratadoComoErrorOcr =
        (r is Coincidencia) ||
        (r is SinCoincidencia && r.probableErrorOcr && r.candidato != null);
    expect(
      tratadoComoErrorOcr,
      isTrue,
      reason: 'debería resolverse como match difuso o como probable typo',
    );
  });

  test('desconocido genuino: no se parece a nada de la base', () {
    final r = matcher.match(item('agua purificada'));
    expect(r, isA<SinCoincidencia>());
    r as SinCoincidencia;
    expect(r.probableErrorOcr, isFalse);
    expect(r.candidato, isNull);
  });

  test('los tres estados no se colapsan: UNKNOWN != coincidencia vacía', () {
    final desconocido = matcher.match(item('agua purificada'));
    final conocido = matcher.match(item('harina de trigo'));
    expect(desconocido.runtimeType, isNot(conocido.runtimeType));
  });
}
