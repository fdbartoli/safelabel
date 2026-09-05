import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/ocr/guia_captura.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/ocr/triage_confianza.dart';

void main() {
  const evaluador = EvaluadorCaptura();
  const triage = TriageConfianza();

  LecturaOcr ocr(List<(String, double)> l) => LecturaOcr([
        for (var i = 0; i < l.length; i++)
          LineaOcr(texto: l[i].$1, confianza: l[i].$2, indice: i),
      ]);

  test('lectura muy corta: sugiere acercarse y encuadrar', () {
    final lectura = ocr([('sal', 0.9)]);
    final s = evaluador.evaluar(lectura, triage.clasificar(lectura));
    expect(s, contains(SugerenciaCaptura.acercarse));
    expect(s, contains(SugerenciaCaptura.encuadrarListaCompleta));
  });

  test('muchas líneas dudosas: sugiere evitar reflejo o movimiento', () {
    final lectura = ocr([
      ('Ingredientes: harina de trigo, azucar, cacao, sal', 0.9),
      ('lecitina de soja y aroma', 0.2),
      ('bicarbonato de sodio', 0.1),
    ]);
    final s = evaluador.evaluar(lectura, triage.clasificar(lectura));
    expect(s, contains(SugerenciaCaptura.evitarReflejoOMovimiento));
  });

  test('texto cortado al final de línea: sugiere girar el envase', () {
    final lectura = ocr([
      ('Ingredientes: harina de trigo, azucar, aceite vege-', 0.9),
      ('tal, sal, leudantes quimicos, vainillina', 0.9),
    ]);
    final s = evaluador.evaluar(lectura, triage.clasificar(lectura));
    expect(s, contains(SugerenciaCaptura.girarEnvase));
  });

  test('hay lista pero falta la línea CONTIENE: sugiere incluirla', () {
    final lectura = ocr([
      ('Ingredientes: harina de trigo enriquecida, azucar, sal, '
          'jarabe de glucosa, lecitina de soja', 0.95),
    ]);
    final s = evaluador.evaluar(lectura, triage.clasificar(lectura));
    expect(s, contains(SugerenciaCaptura.buscarLineaContiene));
  });

  test('lectura completa y nítida: sin sugerencias', () {
    final lectura = ocr([
      ('Ingredientes: harina de trigo enriquecida, azucar, sal, '
          'jarabe de glucosa, lecitina de soja.', 0.95),
      ('CONTIENE: trigo y soja.', 0.95),
    ]);
    final s = evaluador.evaluar(lectura, triage.clasificar(lectura));
    expect(s, isEmpty);
  });
}
