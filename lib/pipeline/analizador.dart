import '../datos/base_conocimiento.dart';
import '../conocimiento/catalogo_conocimiento.dart';
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
  Analizador(
    this.base, {
    CatalogoConocimiento? catalogo,
    this.triage = const TriageConfianza(),
  }) : catalogo = catalogo ?? CatalogoConocimiento.desdeBaseLegacy(base),
       _matcher = catalogo == null
           ? Emparejador(base)
           : Emparejador.desdeCatalogo(catalogo),
       _verificacion = VerificacionCruzada(base);

  final BaseConocimiento base;
  final CatalogoConocimiento catalogo;
  final TriageConfianza triage;
  final Emparejador _matcher;
  final VerificacionCruzada _verificacion;
  static const _normalizador = Normalizador();

  /// Grupos sobre los que la base tiene al menos un ingrediente relacionado.
  /// Un perfil con otro grupo nunca puede dar verde: la base no lo detecta.
  late final Set<String> _gruposCubiertos = {
    for (final c in catalogo.conceptos)
      for (final r in c.relaciones) r.perfilId,
  };

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
          final concepto = m.concepto;

          // Un concepto puede estar relacionado con más de una restricción.
          for (final relacion in concepto.relaciones) {
            final grupoId = relacion.perfilId;
            final grupo = base.grupo(grupoId);
            final nombreGrupo = grupo?.nombre ?? relacion.nombreVisible;

            // Las excepciones siguen en el JSON auxiliar hasta incorporarlas a
            // la base consolidada.
            final nombreNormalizado = _normalizador.normalizarTexto(
              concepto.nombreCanonico,
            );
            final excepcion = base.excepcionPara(nombreNormalizado, grupoId);
            if (excepcion != null) {
              notasExcepciones.add(
                NotaExcepcion(
                  textoLeido: m.item.textoOriginal,
                  grupoAlergeno: nombreGrupo,
                  regla: excepcion.regla,
                  fuente: excepcion.fuente,
                ),
              );
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
            String? aclaracion;
            if (declaracion.hayDeclaracion &&
                !declaracion.contiene.contains(grupoId)) {
              aclaracion =
                  'La línea "CONTIENE" no menciona $nombreGrupo. Puede ser un '
                  'error de lectura de esa línea, una excepción del CAA o un '
                  'incumplimiento de la etiqueta.';
            }

            coincidencias.add(
              HallazgoPerfil(
                textoLeido: m.item.textoOriginal,
                nombreEnBase: concepto.nombreCanonico,
                grupoAlergeno: nombreGrupo,
                porQue:
                    '${concepto.nombreCanonico} está relacionado con '
                    '${relacion.nombreVisible} según la base de conocimiento.',
                certeza: relacion.certeza,
                // Contener el término no es una lectura aproximada: el
                // término está, completo, dentro de lo leído.
                difuso: !m.exacta && !m.porContencion,
                similitud: m.similitud,
                perfilesAfectados: perfilesAfectados,
                severidadMaxima: sevHallazgo,
                fuente: relacion.fuentes,
                origen: declaracion.contiene.contains(grupoId)
                    ? OrigenHallazgo.ambos
                    : OrigenHallazgo.ingrediente,
                padre: m.item.padre,
                aclaracionCruce: aclaracion,
              ),
            );
          }

        case SinCoincidencia():
          noReconocidos.add(
            ItemNoReconocido(
              texto: m.item.textoOriginal,
              probableErrorOcr: m.probableErrorOcr,
              advertenciaReforzada: severidadMaxima == Severidad.anafilaxia,
              candidato: m.candidato,
              padre: m.item.padre,
            ),
          );
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
        coincidencias.add(
          HallazgoPerfil(
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
          ),
        );
      }

      // Fila 2: hueco de la base. Prioridad alta en la cola de desconocidos.
      avisos.add(
        AvisoCruzado(
          grupoAlergeno: nombreGrupo,
          prioridad: PrioridadCola.alta,
          mensaje:
              'La etiqueta declara "CONTIENE $nombreGrupo" pero ningún ingrediente '
              'de la lista lo explica. Falta cobertura en la base para este '
              'producto: queda registrado con prioridad alta.',
        ),
      );
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

    final semaforos = [
      for (final p in perfilesActivos)
        _semaforoDe(
          p,
          items: items,
          coincidencias: coincidencias,
          noReconocidos: noReconocidos,
          noLegibles: noLegibles.length,
          declaracion: declaracion,
        ),
    ];

    return ResultadoAnalisis(
      semaforos: semaforos,
      versionBase: catalogo.version,
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
      ingredientesLeidos: [for (final i in items) i.textoNormalizado],
    );
  }

  /// Semáforo de un perfil: rojo si alguna restricción del perfil coincide;
  /// verde solo si no quedó nada sin verificar para ese perfil; si no, ámbar.
  SemaforoPerfil _semaforoDe(
    Perfil perfil, {
    required List<ItemNormalizado> items,
    required List<HallazgoPerfil> coincidencias,
    required List<ItemNoReconocido> noReconocidos,
    required int noLegibles,
    required DeclaracionAlergenos declaracion,
  }) {
    String nombreGrupo(String id) => base.grupo(id)?.nombre ?? id;
    final propios = [
      for (final h in coincidencias)
        if (h.perfilesAfectados.contains(perfil.nombre)) h,
    ];
    final textosNoReconocidos = {for (final n in noReconocidos) n.texto};

    // Detalle: cada ingrediente leído, con su estado para este perfil.
    final ingredientes = <IngredienteSemaforo>[
      for (final i in items)
        () {
          final choques = [
            for (final h in propios)
              if (h.origen != OrigenHallazgo.lineaContiene &&
                  h.textoLeido == i.textoOriginal)
                h.grupoAlergeno,
          ];
          if (choques.isNotEmpty) {
            return IngredienteSemaforo(
              texto: i.textoNormalizado,
              estado: EstadoIngrediente.choca,
              motivo: choques.toSet().join(', '),
            );
          }
          return IngredienteSemaforo(
            texto: i.textoNormalizado,
            estado: textosNoReconocidos.contains(i.textoOriginal)
                ? EstadoIngrediente.noReconocido
                : EstadoIngrediente.noChoca,
          );
        }(),
      // Lo que solo declara la línea CONTIENE también choca (sección 5.3).
      for (final h in propios)
        if (h.origen == OrigenHallazgo.lineaContiene)
          IngredienteSemaforo(
            texto: 'Declarado en la etiqueta: contiene ${h.grupoAlergeno}',
            estado: EstadoIngrediente.choca,
            motivo: h.grupoAlergeno,
            declarado: true,
          ),
    ];

    final grupos = [for (final r in perfil.restricciones) r.grupoAlergenoId];
    final (color, motivos) = SemaforoPerfil.decidir(
      perfil: perfil.nombre,
      choques: [
        for (final i in ingredientes)
          if (i.estado == EstadoIngrediente.choca) i,
      ],
      noReconocidos: [
        for (final i in ingredientes)
          if (i.estado == EstadoIngrediente.noReconocido) i.texto,
      ],
      noLegibles: noLegibles,
      totalItems: items.length,
      trazas: [
        for (final id in grupos)
          if (declaracion.puedeContener.contains(id)) nombreGrupo(id),
      ],
      sinCobertura: [
        for (final id in grupos)
          if (!_gruposCubiertos.contains(id)) nombreGrupo(id),
      ],
    );
    return SemaforoPerfil(
      perfil: perfil.nombre,
      restricciones: [for (final id in grupos) nombreGrupo(id)],
      color: color,
      motivos: motivos,
      ingredientes: ingredientes,
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
