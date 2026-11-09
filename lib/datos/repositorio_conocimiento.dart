import 'package:sqflite/sqflite.dart';

import '../conocimiento/catalogo_conocimiento.dart';
import '../conocimiento/ids_restricciones.dart';
import '../modelo/consulta_conocimiento.dart';
import '../modelo/ingrediente.dart';
import '../pipeline/normalizador.dart';

class RepositorioConocimiento {
  const RepositorioConocimiento(this._bd);

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
    final denominacionesRaw = await _bd.query(
      'denomination',
      columns: ['name', 'concept_id'],
      orderBy: 'id',
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
    return ConceptoConocimiento(
      id: conceptoId,
      nombreCanonico: conceptoRaw['canonical_name']! as String,
      denominaciones: {
        for (final denominacion in denominacionesRaw)
          if (denominacion['concept_id'] == conceptoId)
            normalizador.normalizarTexto(denominacion['name']! as String):
                denominacion['name']! as String,
      },
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

  Future<ResultadoConsultaConocimiento> buscar(String entrada) async {
    final termino = entrada.trim();
    if (termino.isEmpty) {
      return const ResultadoConsultaConocimiento(
        entrada: '',
        estado: EstadoConsultaConocimiento.unknown,
        coincidencias: [],
      );
    }

    final filas = await _bd.rawQuery(
      '''
      SELECT denomination, MIN(language) AS language,
             concept_id, matched_concept, match_type,
             restriction_id, restriction_name, status
      FROM v_concept_matches
      WHERE denomination = ? COLLATE NOCASE
      GROUP BY denomination, concept_id, matched_concept, match_type,
               restriction_id, restriction_name, status
      ORDER BY restriction_id, match_type
    ''',
      [termino],
    );

    final coincidencias = <CoincidenciaConocimiento>[];
    for (final fila in filas) {
      final conceptoId = fila['concept_id']! as String;
      final restriccionId = fila['restriction_id'] as String?;
      final evidenciasRaw = restriccionId == null
          ? <Map<String, Object?>>[]
          : await _bd.rawQuery(
              '''
        SELECT evidence.fragment, source.id AS source_id,
               source.title, source.url
        FROM evidence
        JOIN source ON source.id = evidence.source_id
        WHERE evidence.concept_id = ? AND evidence.restriction_id = ?
        ORDER BY source.title
      ''',
              [conceptoId, restriccionId],
            );

      final restriccion = restriccionId == null
          ? <Map<String, Object?>>[]
          : await _bd.query(
              'restriction',
              columns: ['display_name'],
              where: 'id = ?',
              whereArgs: [restriccionId],
              limit: 1,
            );

      String? restriccionVisible;
      if (restriccionId != null) {
        restriccionVisible = restriccion.isEmpty
            ? fila['restriction_name']! as String
            : restriccion.first['display_name']! as String;
      }

      coincidencias.add(
        CoincidenciaConocimiento(
          denominacion: fila['denomination']! as String,
          idioma: fila['language']! as String,
          concepto: fila['matched_concept']! as String,
          tipoCoincidencia: fila['match_type'] as String?,
          restriccion: fila['restriction_name'] as String?,
          restriccionVisible: restriccionVisible,
          evidencias: [
            for (final evidencia in evidenciasRaw)
              EvidenciaConocimiento(
                fuente: evidencia['source_id']! as String,
                tituloFuente: evidencia['title']! as String,
                url: evidencia['url']! as String,
                fragmento: evidencia['fragment']! as String,
              ),
          ],
        ),
      );
    }

    var estado = EstadoConsultaConocimiento.unknown;
    if (filas.isNotEmpty) {
      estado = filas.any((fila) => fila['restriction_id'] != null)
          ? EstadoConsultaConocimiento.matched
          : EstadoConsultaConocimiento.recognized;
    }

    return ResultadoConsultaConocimiento(
      entrada: termino,
      estado: estado,
      coincidencias: coincidencias,
    );
  }
}
