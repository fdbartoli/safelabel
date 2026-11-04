// Regresión sobre etiquetas reales (CLAUDE.md, sección 11).
//
// Cada carpeta de test/fixtures/etiquetas/ trae `ocr.txt`: la salida de
// "Ver texto leído" del celular, una línea por renglón del OCR con el formato
// `confianza|bloque|texto`. Acá se corre el análisis completo sobre ese texto,
// sin cámara, y se exige lo que tiene que detectar.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/modelo/resultado_analisis.dart';
import 'package:safelabel/ocr/linea_ocr.dart';
import 'package:safelabel/pipeline/analizador.dart';

import 'ayuda_base.dart';

LecturaOcr leerFixture(String carpeta) {
  final lineas = File('test/fixtures/etiquetas/$carpeta/ocr.txt')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();
  return LecturaOcr([
    for (var i = 0; i < lineas.length; i++)
      () {
        final partes = lineas[i].split('|');
        return LineaOcr(
          confianza: int.parse(partes[0]) / 100,
          bloque: int.parse(partes[1]) - 1,
          texto: partes.sublist(2).join('|'),
          indice: i,
        );
      }(),
  ]);
}

void main() {
  final base = cargarBaseReal();
  const celiaco = Perfil(nombre: 'Mateo', restricciones: [
    RestriccionPerfil(grupoAlergenoId: 'trigo', severidad: Severidad.moderada),
  ]);

  group('fideos-harina-000 (primera prueba en celular)', () {
    late ResultadoAnalisis r;
    setUpAll(() {
      r = Analizador(base).analizar(
        leerFixture('fideos-harina-000'),
        perfilesActivos: [celiaco],
      );
    });

    test('la harina de trigo de la lista se detecta como ingrediente', () {
      final desdeLista = r.coincidencias.where(
        (h) =>
            h.grupoAlergeno == 'cereales con gluten' &&
            h.origen != OrigenHallazgo.lineaContiene,
      );
      expect(desdeLista, isNotEmpty,
          reason: 'la harina de trigo tiene que salir aunque no hubiera línea '
              'CONTIENE');
    });

    test('lee "CONTIENE DERIVADOS DE TRIGO" aunque siga en el mismo renglón',
        () {
      expect(r.declaracion.contiene, contains('trigo'));
    });

    test('lee "PUEDE CONTENER SOJA Y HUEVO" partido en dos renglones', () {
      expect(r.declaracion.puedeContener, containsAll(['soja', 'huevo']));
    });

    test('el texto publicitario antes de INGREDIENTES no se analiza', () {
      final textos = r.diagnostico!.items.map((i) => i.textoNormalizado);
      expect(textos.where((t) => t.contains('alimentacidn')), isEmpty);
      expect(textos, isNot(contains('ingredientes')));
    });

    test('los fortificantes de la Ley 25.630 conservan su nombre', () {
      final textos =
          r.diagnostico!.items.map((i) => i.textoNormalizado).toList();
      expect(textos, contains('sulfato ferroso'));
      expect(textos, contains('niacina'));
      expect(textos, contains('acido folico'));
      expect(textos.where((t) => t.contains('mg/kg')), isEmpty);
    });
  });
}
