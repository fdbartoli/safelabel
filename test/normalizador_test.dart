import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/pipeline/normalizador.dart';

void main() {
  const n = Normalizador();

  group('normalizarTexto', () {
    test('minúsculas y sin acentos', () {
      expect(n.normalizarTexto('Caseinato de SODIO'), 'caseinato de sodio');
      expect(n.normalizarTexto('Almidón modificado'), 'almidon modificado');
      expect(n.normalizarTexto('MANÍ'), 'mani');
      expect(n.normalizarTexto('jalapeño'), 'jalapeno');
    });

    test('colapsa espacios y recorta', () {
      expect(n.normalizarTexto('  lecitina   de  soja \n'), 'lecitina de soja');
    });
  });

  group('separarIngredientes', () {
    test('separa por comas, punto y coma y saltos de línea', () {
      final items = n.separarIngredientes('Azúcar, sal; agua\nvinagre');
      expect(items.map((e) => e.textoNormalizado), [
        'azucar',
        'sal',
        'agua',
        'vinagre',
      ]);
    });

    test('quita el encabezado "Ingredientes:"', () {
      final items = n.separarIngredientes('INGREDIENTES: harina, agua.');
      expect(items.map((e) => e.textoNormalizado), ['harina', 'agua']);
    });

    test('resuelve anidados y registra el padre — chocolate (leche, lecitina de soja)', () {
      final items = n.separarIngredientes(
        'chocolate (leche, lecitina de soja)',
      );
      expect(items.length, 3);
      expect(items[0].textoNormalizado, 'chocolate');
      expect(items[0].padre, isNull);
      expect(items[1].textoNormalizado, 'leche');
      expect(items[1].padre, 'chocolate');
      expect(items[2].textoNormalizado, 'lecitina de soja');
      expect(items[2].padre, 'chocolate');
    });

    test('anidado seguido de otro ingrediente de primer nivel', () {
      final items = n.separarIngredientes(
        'galletita (harina de trigo, azucar), dulce de leche',
      );
      expect(items.map((e) => e.textoNormalizado), [
        'galletita',
        'harina de trigo',
        'azucar',
        'dulce de leche',
      ]);
      expect(items[1].padre, 'galletita');
      expect(items[3].padre, isNull);
    });

    test('detecta y canonicaliza números INS', () {
      expect(
        n.separarIngredientes('emulsionante ins 322').single.ins,
        'ins 322',
      );
      expect(
        n.separarIngredientes('INS322').single.textoNormalizado,
        'ins 322',
      );
      expect(n.separarIngredientes('322').single.ins, 'ins 322');
      expect(n.separarIngredientes('E 471').single.ins, 'ins 471');
      expect(n.separarIngredientes('colorante: 150d').single.ins, 'ins 150d');
      expect(
        n.separarIngredientes('emulsionante e322').single.textoNormalizado,
        'ins 322',
      );
    });

    test('descarta el bloque de tabla nutricional', () {
      final texto =
          'Ingredientes: harina, sal.\n'
          'Información nutricional\n'
          'Valor energético 400 kcal\n'
          'Carbohidratos 80 g';
      final items = n.separarIngredientes(texto);
      expect(items.map((e) => e.textoNormalizado), ['harina', 'sal']);
    });

    test('corta antes de la línea CONTIENE (la lee otro paso)', () {
      final texto = 'Ingredientes: harina, sal.\nCONTIENE trigo.';
      final items = n.separarIngredientes(texto);
      expect(items.map((e) => e.textoNormalizado), ['harina', 'sal']);
    });

    test('corta CONTIENE aunque venga a mitad de línea', () {
      final texto =
          'Ingredientes: harina, sal. CONTIENE trigo. Puede contener leche.';
      final items = n.separarIngredientes(texto);
      expect(items.map((e) => e.textoNormalizado), ['harina', 'sal']);
    });

    test('no confunde "no contiene" con el bloque de alérgenos', () {
      final texto = 'Ingredientes: harina, sal.\nNo contiene TACC.';
      final items = n.separarIngredientes(texto);
      expect(items.map((e) => e.textoNormalizado), ['harina', 'sal']);
    });

    test('descarta prefijo de categoría "colorante:"', () {
      final items = n.separarIngredientes('colorante: caramelo, sal');
      expect(items.map((e) => e.textoNormalizado), ['caramelo', 'sal']);
    });

    test('no rompe con paréntesis sin cerrar', () {
      final items = n.separarIngredientes('mezcla (leche, soja');
      expect(
        items.map((e) => e.textoNormalizado),
        containsAll(['mezcla', 'leche', 'soja']),
      );
    });
  });
}
