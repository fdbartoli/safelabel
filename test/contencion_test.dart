import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/pipeline/matcher.dart';
import 'package:safelabel/pipeline/normalizador.dart';

import 'ayuda_base.dart';

/// Match por contención: un nombre comercial largo que contiene un término con
/// alérgeno tiene que detectarse aunque no esté tal cual en la base.
void main() {
  final base = cargarBaseReal();
  final emparejador = Emparejador(base);
  const n = Normalizador();

  List<ResultadoMatch> analizar(String texto) =>
      emparejador.matchTodos(n.separarIngredientes(texto));

  /// Restricciones de cada coincidencia; `null` si coincidió con un concepto
  /// sin restricción ("manteca de cacao").
  Set<String?> grupos(String texto) => {
    for (final m in analizar(texto))
      if (m is Coincidencia)
        if (m.concepto.relaciones.isEmpty)
          null
        else
          for (final r in m.concepto.relaciones) r.perfilId,
  };

  test('"harina de trigo tipo 000 enriquecida" contiene harina de trigo', () {
    final m = analizar('harina de trigo tipo 000 enriquecida').single;
    expect(m, isA<Coincidencia>());
    m as Coincidencia;
    expect(m.porContencion, isTrue);
    expect(m.concepto.relaciones.map((r) => r.perfilId), contains('trigo'));
  });

  test('un ítem con dos alérgenos genera una coincidencia por grupo', () {
    expect(grupos('galletitas de trigo con leche entera'),
        containsAll(['trigo', 'leche']));
  });

  test('"aceite de mani" no se confunde con "aceite de maiz"', () {
    expect(grupos('aceite de mani refinado'), contains('mani'));
  });

  test('un match exacto sin alérgeno manda sobre la contención', () {
    // "manteca de cacao" es cacao, no manteca (leche).
    expect(grupos('manteca de cacao'), {null});
  });

  test('las palabras cortas no disparan contención', () {
    // "sal" no tiene alérgeno, pero tampoco debe "contener" nada por letras.
    expect(analizar('sal marina gruesa').whereType<Coincidencia>(), isEmpty);
  });
}
