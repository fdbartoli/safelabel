import 'linea_ocr.dart';
import 'triage_confianza.dart';

/// Guía de captura (paso 1 / sección 6). En la Etapa 1 la guía se evalúa a
/// partir de lo que devolvió el OCR, no de análisis de imagen en vivo: si la
/// lectura salió pobre, se le dice a la persona hacia dónde corregir, siempre
/// en positivo.
enum SugerenciaCaptura {
  acercarse,
  encuadrarListaCompleta,
  girarEnvase,
  evitarReflejoOMovimiento,
  buscarLineaContiene,
}

extension MensajeSugerencia on SugerenciaCaptura {
  String get mensaje {
    switch (this) {
      case SugerenciaCaptura.acercarse:
        return 'Acercate un poco más a la lista de ingredientes.';
      case SugerenciaCaptura.encuadrarListaCompleta:
        return 'Encuadrá toda la lista de ingredientes dentro de la guía.';
      case SugerenciaCaptura.girarEnvase:
        return 'Girá el envase despacio: parece que el texto sigue en la curva.';
      case SugerenciaCaptura.evitarReflejoOMovimiento:
        return 'Hay reflejo o movimiento en parte del texto. Movete un poco y repetí la foto.';
      case SugerenciaCaptura.buscarLineaContiene:
        return 'Incluí también la línea "CONTIENE" que va después de los ingredientes.';
    }
  }
}

class EvaluadorCaptura {
  const EvaluadorCaptura({
    this.minCaracteres = 40,
    this.minLineas = 2,
    this.proporcionDudosaParaAviso = 0.25,
  });

  final int minCaracteres;
  final int minLineas;
  final double proporcionDudosaParaAviso;

  List<SugerenciaCaptura> evaluar(LecturaOcr lectura, ResultadoTriage triage) {
    final sugerencias = <SugerenciaCaptura>[];
    final texto = lectura.textoCompleto.trim();

    if (texto.length < minCaracteres || triage.legibles.length < minLineas) {
      sugerencias.add(SugerenciaCaptura.acercarse);
      sugerencias.add(SugerenciaCaptura.encuadrarListaCompleta);
    }

    final total = lectura.lineas.where((l) => l.texto.trim().isNotEmpty).length;
    if (total > 0 &&
        triage.noLegibles.length / total >= proporcionDudosaParaAviso) {
      sugerencias.add(SugerenciaCaptura.evitarReflejoOMovimiento);
    }

    final terminaCortado = RegExp(r'[-‐]\s*$', multiLine: true);
    if (terminaCortado.hasMatch(texto)) {
      sugerencias.add(SugerenciaCaptura.girarEnvase);
    }

    final tieneEncabezado = RegExp(
      r'ingredientes?\s*:',
      caseSensitive: false,
    ).hasMatch(texto);
    final tieneContiene = RegExp(
      r'\bcontiene\b',
      caseSensitive: false,
    ).hasMatch(texto);
    if (tieneEncabezado && !tieneContiene) {
      sugerencias.add(SugerenciaCaptura.buscarLineaContiene);
    }

    return sugerencias.toSet().toList();
  }
}
