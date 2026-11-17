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

    test('descarta un porcentaje aislado dentro de paréntesis', () {
      final items = n.separarIngredientes('maní tostado (40%)');
      expect(items.map((e) => e.textoNormalizado), ['mani tostado']);
    });

    test('descarta ley y cantidades sin borrar números del ingrediente', () {
      final texto =
          'INGREDIENTES:\n'
          'Harina de trigo tipo 000 enriquecida\n'
          'Ley N° 25.630 (sulfato ferroso:\n'
          '30 mg/kg -como hierro-, niacina:\n'
          '13 mg/kg, vitamina B1: 6.3 mg/kg,\n'
          'ácido fólico: 2.2 mg/kg, vitamina B2:\n'
          '1.3 mg/kg), huevo.\n'
          'CONTIENE HUEVO Y DERIVADOS DE TRIGO.';

      final items = n.separarIngredientes(texto);

      expect(items.map((e) => e.textoNormalizado), [
        'harina de trigo tipo 000 enriquecida',
        'sulfato ferroso',
        'niacina',
        'vitamina b1',
        'acido folico',
        'vitamina b2',
        'huevo',
      ]);
    });

    test('conserva números semánticos y descarta una cantidad suelta', () {
      final items = n.separarIngredientes(
        'harina tipo 000, vitamina B1, INS 322, 30 mg/kg',
      );
      expect(items.map((e) => e.textoNormalizado), [
        'harina tipo 000',
        'vitamina b1',
        'ins 322',
      ]);
    });

    group('separa conjunciones usando solo coincidencias exactas', () {
      final terminosExactos = {
        'agua',
        'cacao',
        'sorbato potasico',
        'benzoato sodico',
        'aroma de humo',
        'aceite de palma interesterificado y fraccionado',
        'aceite de girasol alto oleico',
        'aceite de soja totalmente hidrogenado',
      };

      bool existeExacto(String termino) => terminosExactos.contains(termino);

      test('conserva primero un término completo exacto', () {
        final items = n.separarIngredientes(
          'aceite de palma interesterificado y fraccionado',
          existeTerminoExacto: existeExacto,
        );
        expect(items.map((e) => e.textoNormalizado), [
          'aceite de palma interesterificado y fraccionado',
        ]);
      });

      test('separa dos términos exactos', () {
        final items = n.separarIngredientes(
          'sorbato potásico y benzoato sódico',
          existeTerminoExacto: existeExacto,
        );
        expect(items.map((e) => e.textoNormalizado), [
          'sorbato potasico',
          'benzoato sodico',
        ]);
      });

      test('separa aceites que son términos exactos independientes', () {
        final items = n.separarIngredientes(
          'aceite de girasol alto oleico y aceite de soja totalmente hidrogenado',
          existeTerminoExacto: existeExacto,
        );
        expect(items.map((e) => e.textoNormalizado), [
          'aceite de girasol alto oleico',
          'aceite de soja totalmente hidrogenado',
        ]);
      });

      test('separa un núcleo repetido aunque un lado siga desconocido', () {
        final items = n.separarIngredientes(
          'aroma y aroma de humo',
          existeTerminoExacto: existeExacto,
        );
        expect(items.map((e) => e.textoNormalizado), [
          'aroma',
          'aroma de humo',
        ]);
      });

      test('separa un término exacto de otro ingrediente compuesto', () {
        final items = n.separarIngredientes(
          'agua y esencia natural',
          existeTerminoExacto: existeExacto,
        );
        expect(items.map((e) => e.textoNormalizado), [
          'agua',
          'esencia natural',
        ]);
      });

      test('separa una palabra desconocida junto a un término exacto', () {
        for (final entrada in ['aroma y cacao', 'cacao y aroma']) {
          final items = n.separarIngredientes(
            entrada,
            existeTerminoExacto: existeExacto,
          );
          expect(items.map((e) => e.textoNormalizado).toSet(), {
            'aroma',
            'cacao',
          }, reason: entrada);
        }
      });

      test('no separa dos modificadores desconocidos', () {
        final items = n.separarIngredientes(
          'interesterificado y fraccionado',
          existeTerminoExacto: existeExacto,
        );
        expect(items.map((e) => e.textoNormalizado), [
          'interesterificado y fraccionado',
        ]);
      });

      test('no expande abreviaturas coordinadas fuera del alcance', () {
        final items = n.separarIngredientes(
          'vitamina a y d',
          existeTerminoExacto: (termino) => termino == 'vitamina a',
        );
        expect(items.map((e) => e.textoNormalizado), ['vitamina a y d']);
      });
    });
  });
}
