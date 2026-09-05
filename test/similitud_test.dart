import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/pipeline/similitud.dart';

void main() {
  test('distanciaLevenshtein básica', () {
    expect(distanciaLevenshtein('caseinato', 'caseinato'), 0);
    expect(distanciaLevenshtein('caseinato', 'caselnato'), 1);
    expect(distanciaLevenshtein('sodio', 'sodlo'), 1);
    expect(distanciaLevenshtein('', 'abc'), 3);
  });

  test('ratioLevenshtein normaliza a [0,1]', () {
    expect(ratioLevenshtein('leche', 'leche'), 1.0);
    expect(ratioLevenshtein('leche', 'lecha'), closeTo(0.8, 0.001));
  });

  test('coeficienteDice tolera palabras de más', () {
    expect(coeficienteDice('lecitina de soja', 'lecitina de soja'), 1.0);
    expect(coeficienteDice('lecitina soja', 'lecitina de soja'),
        greaterThan(0.8));
  });

  test('similitud combinada: typo de OCR queda alto', () {
    // "caselnato de sodlo" es la lectura errónea típica de "caseinato de sodio".
    expect(similitud('caselnato de sodlo', 'caseinato de sodio'),
        greaterThan(0.84));
  });

  test('similitud combinada: términos distintos quedan bajo', () {
    expect(similitud('espinaca', 'caseinato de sodio'), lessThan(0.4));
  });
}
