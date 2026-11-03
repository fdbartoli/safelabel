import 'package:sqflite/sqflite.dart';

import '../modelo/consulta_conocimiento.dart';

class RepositorioConocimiento {
  const RepositorioConocimiento(this._bd);

  final Database _bd;

  Future<ResultadoConsultaConocimiento> buscar(String entrada) async {
    final termino = entrada.trim();
    if (termino.isEmpty) {
      return const ResultadoConsultaConocimiento(
        entrada: '',
        coincidencias: [],
      );
    }

    final filas = await _bd.rawQuery('''
      SELECT denomination, language, concept_id, matched_concept,
             match_type, restriction_id, restriction_name
      FROM v_restriction_matches
      WHERE denomination = ? COLLATE NOCASE
      ORDER BY restriction_id, match_type
    ''', [termino]);

    final coincidencias = <CoincidenciaConocimiento>[];
    for (final fila in filas) {
      final conceptoId = fila['concept_id']! as String;
      final restriccionId = fila['restriction_id']! as String;
      final evidenciasRaw = await _bd.rawQuery('''
        SELECT evidence.fragment, source.id AS source_id,
               source.title, source.url
        FROM evidence
        JOIN source ON source.id = evidence.source_id
        WHERE evidence.concept_id = ? AND evidence.restriction_id = ?
        ORDER BY source.title
      ''', [conceptoId, restriccionId]);

      final restriccion = await _bd.query(
        'restriction',
        columns: ['display_name'],
        where: 'id = ?',
        whereArgs: [restriccionId],
        limit: 1,
      );

      coincidencias.add(
        CoincidenciaConocimiento(
          denominacion: fila['denomination']! as String,
          idioma: fila['language']! as String,
          concepto: fila['matched_concept']! as String,
          tipoCoincidencia: fila['match_type']! as String,
          restriccion: fila['restriction_name']! as String,
          restriccionVisible: restriccion.isEmpty
              ? fila['restriction_name']! as String
              : restriccion.first['display_name']! as String,
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

    return ResultadoConsultaConocimiento(
      entrada: termino,
      coincidencias: coincidencias,
    );
  }
}
