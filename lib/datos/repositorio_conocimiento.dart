import 'package:sqflite/sqflite.dart';

import '../conocimiento/catalogo_conocimiento.dart';
import '../conocimiento/ids_restricciones.dart';
import '../modelo/consulta_conocimiento.dart';
import '../modelo/ingrediente.dart';
import '../pipeline/matcher.dart';
import '../pipeline/normalizador.dart';

class RepositorioConocimiento {
  RepositorioConocimiento(this._bd);

  final Database _bd;

  Future<CatalogoConocimiento> cargarCatalogo() async {
    const normalizador = Normalizador();
    final versionRaw = await _bd.query(
      'release_metadata',
      columns: ['version'],
      limit: 1,
    );
    final version = versionRaw.isEmpty
        ? 'sin-version'
        : versionRaw.first['version']! as String;

    final conceptosRaw = await _bd.query(
      'concept',
      columns: ['id', 'canonical_name'],
      orderBy: 'canonical_name',
    );
    // Español primero: varias denominaciones normalizan igual ("caseinato de
    // sódio" en portugués y "caseinato de sodio") y la primera que se carga
    // es la que se muestra.
    final denominacionesRaw = await _bd.query(
      'denomination',
      columns: ['name', 'concept_id'],
      orderBy: "CASE WHEN language LIKE 'es%' THEN 0 ELSE 1 END, id",
    );
    final relacionesRaw = await _bd.rawQuery('''
      SELECT cr.concept_id, cr.restriction_id, cr.match_type,
             r.name, r.display_name
      FROM concept_restriction cr
      JOIN restriction r ON r.id = cr.restriction_id
      ORDER BY cr.concept_id, cr.restriction_id
    ''');
    final evidenciasRaw = await _bd.rawQuery('''
      SELECT e.concept_id, e.restriction_id, e.fragment,
             s.id AS source_id, s.title, s.url
      FROM evidence e
      JOIN source s ON s.id = e.source_id
      ORDER BY e.concept_id, e.restriction_id, s.title
    ''');

    return CatalogoConocimiento(
      version: version,
      conceptos: [
        for (final conceptoRaw in conceptosRaw)
          _construirConcepto(
            conceptoRaw,
            denominacionesRaw,
            relacionesRaw,
            evidenciasRaw,
            normalizador,
          ),
      ],
    );
  }

  ConceptoConocimiento _construirConcepto(
    Map<String, Object?> conceptoRaw,
    List<Map<String, Object?>> denominacionesRaw,
    List<Map<String, Object?>> relacionesRaw,
    List<Map<String, Object?>> evidenciasRaw,
    Normalizador normalizador,
  ) {
    final conceptoId = conceptoRaw['id']! as String;
    // Si dos denominaciones normalizan igual, se queda la primera (español,
    // por el orden de la consulta): un literal de mapa se quedaría con la
    // última.
    final denominaciones = <String, String>{};
    for (final denominacion in denominacionesRaw) {
      if (denominacion['concept_id'] != conceptoId) continue;
      final nombre = denominacion['name']! as String;
      denominaciones.putIfAbsent(
        normalizador.normalizarTexto(nombre),
        () => nombre,
      );
    }
    return ConceptoConocimiento(
      id: conceptoId,
      nombreCanonico: conceptoRaw['canonical_name']! as String,
      denominaciones: denominaciones,
      relaciones: [
        for (final relacion in relacionesRaw)
          if (relacion['concept_id'] == conceptoId)
            RelacionRestriccion(
              restriccionId: relacion['restriction_id']! as String,
              perfilId: idPerfilParaRestriccion(
                relacion['restriction_id']! as String,
              ),
              nombre: relacion['name']! as String,
              nombreVisible: relacion['display_name']! as String,
              tipo: relacion['match_type']! as String,
              certeza: Certeza.seguro,
              evidencias: [
                for (final evidencia in evidenciasRaw)
                  if (evidencia['concept_id'] == conceptoId &&
                      evidencia['restriction_id'] == relacion['restriction_id'])
                    EvidenciaCatalogo(
                      fuenteId: evidencia['source_id']! as String,
                      titulo: evidencia['title']! as String,
                      url: evidencia['url']! as String,
                      fragmento: evidencia['fragment']! as String,
                    ),
              ],
            ),
      ],
    );
  }

  /// Matcher sobre el catálogo, armado una sola vez por repositorio.
  late final Future<Emparejador> _emparejador = cargarCatalogo().then(
    Emparejador.desdeCatalogo,
  );

  /// Busca un ingrediente suelto con el mismo criterio que el análisis de una
  /// etiqueta: normaliza (minúsculas, sin tildes) y empareja exacto →
  /// contención → aproximado → desconocido. Así la consulta y el escaneo nunca
  /// dan resultados distintos para el mismo texto.
  Future<ResultadoConsultaConocimiento> buscar(String entrada) async {
    final termino = entrada.trim();
    const normalizador = Normalizador();
    final normalizado = normalizador.normalizarTexto(termino);
    if (normalizado.isEmpty) {
      return ResultadoConsultaConocimiento(
        entrada: termino,
        estado: EstadoConsultaConocimiento.unknown,
        coincidencias: const [],
      );
    }

    final emparejador = await _emparejador;
    final matches = emparejador.matchTodos([
      ItemNormalizado(textoOriginal: termino, textoNormalizado: normalizado),
    ]);

    final coincidencias = <CoincidenciaConocimiento>[];
    for (final m in matches) {
      switch (m) {
        case Coincidencia():
          final tipo = m.exacta
              ? TipoCoincidenciaConsulta.exacta
              : m.porContencion
              ? TipoCoincidenciaConsulta.contiene
              : TipoCoincidenciaConsulta.aproximada;
          final concepto = m.concepto;
          if (concepto.relaciones.isEmpty) {
            coincidencias.add(
              CoincidenciaConocimiento(
                denominacion: m.terminoBase,
                concepto: concepto.nombreCanonico,
                tipoCoincidencia: null,
                restriccion: null,
                restriccionVisible: null,
                evidencias: const [],
                coincidencia: tipo,
                similitud: m.similitud,
              ),
            );
            continue;
          }
          for (final relacion in concepto.relaciones) {
            coincidencias.add(
              CoincidenciaConocimiento(
                denominacion: m.terminoBase,
                concepto: concepto.nombreCanonico,
                tipoCoincidencia: relacion.tipo,
                restriccion: relacion.nombre,
                restriccionVisible: relacion.nombreVisible,
                evidencias: [
                  for (final e in relacion.evidencias)
                    EvidenciaConocimiento(
                      fuente: e.fuenteId,
                      tituloFuente: e.titulo,
                      url: e.url,
                      fragmento: e.fragmento,
                    ),
                ],
                coincidencia: tipo,
                similitud: m.similitud,
              ),
            );
          }
        case SinCoincidencia():
          // Sin coincidencia: se distingue "se parece a algo" (probable
          // error de escritura) de "no se parece a nada" (sección 5.1).
          return ResultadoConsultaConocimiento(
            entrada: termino,
            estado: m.probableErrorOcr && m.candidato != null
                ? EstadoConsultaConocimiento.parecido
                : EstadoConsultaConocimiento.unknown,
            coincidencias: const [],
            sugerencia: m.probableErrorOcr ? m.candidato : null,
            similitudSugerencia: m.probableErrorOcr ? m.mejorSimilitud : null,
          );
      }
    }

    return ResultadoConsultaConocimiento(
      entrada: termino,
      estado: coincidencias.any((c) => c.tieneRestriccion)
          ? EstadoConsultaConocimiento.matched
          : EstadoConsultaConocimiento.recognized,
      coincidencias: coincidencias,
    );
  }
}
