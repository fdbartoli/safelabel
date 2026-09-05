import '../datos/base_conocimiento.dart';
import '../modelo/ingrediente.dart';
import '../modelo/perfil.dart';
import '../modelo/resultado_analisis.dart';
import '../ocr/linea_ocr.dart';
import '../ocr/triage_confianza.dart';
import 'matcher.dart';
import 'normalizador.dart';
import 'verificacion_cruzada.dart';

/// Orquesta los pasos 3 a 8 del Flujo B y arma el resultado en tres bloques.
///
/// No decide alérgenos: encadena triage → normalización → match → verificación
/// cruzada → cruce con perfiles, y cada determinación sale de la base local.
class Analizador {
  Analizador(this.base, {this.triage = const TriageConfianza()})
      : _matcher = Emparejador(base),
        _verificacion = VerificacionCruzada(base);

  final BaseConocimiento base;
  final TriageConfianza triage;
  final Emparejador _matcher;
  final VerificacionCruzada _verificacion;
  static const _normalizador = Normalizador();

  ResultadoAnalisis analizar(
    LecturaOcr lectura, {
    required List<Perfil> perfilesActivos,
  }) {
    // Paso 3: triage de confianza.
    final t = triage.clasificar(lectura);

    // Paso 6 (parte lectura): declaración CONTIENE / PUEDE CONTENER.
    final declaracion = _verificacion.analizar(t.textoLegible);

    // Paso 4: normalización de la lista de ingredientes.
    final items = _normalizador.separarIngredientes(t.textoLegible);

    // Paso 5: match.
    final matches = _matcher.matchTodos(items);

    final severidadMaxima = _severidadMaxima(perfilesActivos);

    // Paso 7 y 8: cruce con perfiles y armado de bloques.
    final coincidencias = <HallazgoPerfil>[];
    final noReconocidos = <ItemNoReconocido>[];
    final notasExcepciones = <NotaExcepcion>[];
    final gruposDetectadosEnIngredientes = <String>{};

    for (final m in matches) {
      switch (m) {
        case Coincidencia():
          final ing = m.ingrediente;

          // Término conocido y sin alérgeno asociado: cuenta como analizado y no
          // genera hallazgo. No es un veredicto de aptitud (regla 1.4).
          final grupoId = ing.grupoAlergenoId;
          if (grupoId == null) continue;

          final grupo = base.grupo(grupoId);
          final nombreGrupo = grupo?.nombre ?? grupoId;

          // Sección 5.4: excepción del CAA modelada como regla.
          final excepcion = base.excepcionPara(
            ing.nombreNormalizado,
            grupoId,
          );
          if (excepcion != null) {
            notasExcepciones.add(NotaExcepcion(
              textoLeido: m.item.textoOriginal,
              grupoAlergeno: nombreGrupo,
              regla: excepcion.regla,
              fuente: excepcion.fuente,
            ));
            continue;
          }

          gruposDetectadosEnIngredientes.add(grupoId);

          final perfilesAfectados = [
            for (final p in perfilesActivos)
              if (p.restringe(grupoId)) p.nombre,
          ];
          if (perfilesAfectados.isEmpty) continue;

          final sevHallazgo = _severidadMaximaGrupo(
            perfilesActivos,
            grupoId,
          )!;

          // Sección 5.3, fila 3: el ingrediente marca alérgeno pero la línea
          // CONTIENE no lo declara.
          String? aclaracion;
          if (declaracion.hayDeclaracion &&
              !declaracion.contiene.contains(grupoId)) {
            aclaracion =
                'La línea "CONTIENE" no menciona $nombreGrupo. Puede ser un '
                'error de lectura de esa línea, una excepción del CAA o un '
                'incumplimiento de la etiqueta.';
          }

          coincidencias.add(HallazgoPerfil(
            textoLeido: m.item.textoOriginal,
            nombreEnBase: ing.nombreCanonico,
            grupoAlergeno: nombreGrupo,
            porQue: ing.explicacion,
            certeza: ing.certeza,
            difuso: !m.exacta,
            similitud: m.similitud,
            perfilesAfectados: perfilesAfectados,
            severidadMaxima: sevHallazgo,
            fuente: ing.fuente,
            origen: declaracion.contiene.contains(grupoId)
                ? OrigenHallazgo.ambos
                : OrigenHallazgo.ingrediente,
            padre: m.item.padre,
            aclaracionCruce: aclaracion,
          ));

        case SinCoincidencia():
          noReconocidos.add(ItemNoReconocido(
            texto: m.item.textoOriginal,
            probableErrorOcr: m.probableErrorOcr,
            advertenciaReforzada: severidadMaxima == Severidad.anafilaxia,
            candidato: m.candidato,
            padre: m.item.padre,
          ));
      }
    }

    // Sección 5.3, filas 1 y 2: la línea CONTIENE declara un alérgeno que el
    // análisis de ingredientes no cubrió.
    final avisos = <AvisoCruzado>[];
    for (final grupoId in declaracion.contiene) {
      if (gruposDetectadosEnIngredientes.contains(grupoId)) continue;
      final grupo = base.grupo(grupoId);
      final nombreGrupo = grupo?.nombre ?? grupoId;

      final perfilesAfectados = [
        for (final p in perfilesActivos)
          if (p.restringe(grupoId)) p.nombre,
      ];

      if (perfilesAfectados.isNotEmpty) {
        // Fila 1: se usa la declaración de la etiqueta; el hueco de la base
        // queda cubierto para este análisis.
        coincidencias.add(HallazgoPerfil(
          textoLeido: 'línea "CONTIENE $nombreGrupo"',
          nombreEnBase: nombreGrupo,
          grupoAlergeno: nombreGrupo,
          porQue:
              'La etiqueta declara expresamente que el producto contiene '
              '$nombreGrupo, según la fórmula del Art. 235 séptimo del CAA. '
              'Ningún ingrediente de la lista analizada se corresponde con este '
              'grupo en la base, así que el dato proviene de la propia etiqueta.',
          certeza: Certeza.seguro,
          difuso: false,
          similitud: 1,
          perfilesAfectados: perfilesAfectados,
          severidadMaxima: _severidadMaximaGrupo(perfilesActivos, grupoId)!,
          fuente: 'Etiqueta (línea CONTIENE) · CAA art. 235 séptimo',
          origen: OrigenHallazgo.lineaContiene,
        ));
      }

      // Fila 2: hueco de la base. Prioridad alta en la cola de desconocidos.
      avisos.add(AvisoCruzado(
        grupoAlergeno: nombreGrupo,
        prioridad: PrioridadCola.alta,
        mensaje:
            'La etiqueta declara "CONTIENE $nombreGrupo" pero ningún ingrediente '
            'de la lista lo explica. Falta cobertura en la base para este '
            'producto: queda registrado con prioridad alta.',
      ));
    }

    // Bloque 3.
    final noLegibles = [
      for (final l in t.noLegibles)
        ItemNoLegible(
          lineaIndice: l.indice,
          textoParcial: l.texto,
          confianza: l.confianza,
        ),
    ];

    final itemsAnalizados = items.length - noReconocidos.length;

    return ResultadoAnalisis(
      versionBase: base.version,
      perfilesActivos: [for (final p in perfilesActivos) p.nombre],
      coincidencias: coincidencias,
      noReconocidos: noReconocidos,
      noLegibles: noLegibles,
      notasExcepciones: notasExcepciones,
      avisosCruce: avisos,
      declaracion: declaracion,
      totalItems: items.length,
      itemsAnalizados: itemsAnalizados < 0 ? 0 : itemsAnalizados,
      severidadMaxima: severidadMaxima,
    );
  }

  Severidad? _severidadMaxima(List<Perfil> perfiles) {
    Severidad? max;
    for (final p in perfiles) {
      for (final r in p.restricciones) {
        if (max == null || r.severidad.orden > max.orden) max = r.severidad;
      }
    }
    return max;
  }

  Severidad? _severidadMaximaGrupo(List<Perfil> perfiles, String grupoId) {
    Severidad? max;
    for (final p in perfiles) {
      final s = p.severidadPara(grupoId);
      if (s != null && (max == null || s.orden > max.orden)) max = s;
    }
    return max;
  }
}
