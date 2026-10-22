import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import '../pipeline/matcher.dart';
import '../pipeline/normalizador.dart';
import 'servicio_reemplazos.dart';

/// Una sugerencia del LLM que el filtro descartó.
class SugerenciaDescartada {
  const SugerenciaDescartada({
    required this.nombre,
    required this.terminoEncontrado,
    required this.grupoAlergeno,
  });

  final String nombre;

  /// Qué término de la base apareció en el nombre ("almendra").
  final String terminoEncontrado;

  final String grupoAlergeno;
}

class ResultadoFiltro {
  const ResultadoFiltro({required this.aceptadas, required this.descartadas});
  final List<SugerenciaReemplazo> aceptadas;
  final List<SugerenciaDescartada> descartadas;
}

/// Red de seguridad determinista sobre lo que propone el LLM (sección 5.6).
///
/// El LLM no decide nada: cada sugerencia se compara contra la base local y
/// se descarta si menciona un ingrediente o un grupo que algún perfil activo
/// restringe. Ante la duda descarta — un descarte de más no lastima a nadie,
/// uno de menos puede ser una reacción alérgica.
class FiltroReemplazos {
  FiltroReemplazos(this.base, List<Perfil> perfilesActivos)
    : _emparejador = Emparejador(base) {
    final restringidos = {
      for (final p in perfilesActivos)
        for (final r in p.restricciones) r.grupoAlergenoId,
    };
    for (final grupoId in restringidos) {
      final grupo = base.grupo(grupoId);
      if (grupo == null) continue;
      void agregar(String termino) {
        final n = _normalizador.normalizarTexto(termino);
        if (n.length >= 3) _terminos[n] = grupoId;
      }

      agregar(grupo.id);
      agregar(grupo.nombre);
      for (final t in grupo.textoEtiqueta.split(
        RegExp(r',|;|/|\by/o\b|\by\b|\bo\b'),
      )) {
        agregar(t.trim());
      }
      if (grupoId == 'trigo') agregar('gluten');
    }
    for (final termino in base.terminosIndexados) {
      final grupoId = base.matchExacto(termino)?.grupoAlergenoId;
      if (grupoId != null && restringidos.contains(grupoId)) {
        _terminos.putIfAbsent(termino, () => grupoId);
      }
    }
  }

  final BaseConocimiento base;
  final Emparejador _emparejador;
  static const _normalizador = Normalizador();

  /// término normalizado → id de grupo restringido.
  final Map<String, String> _terminos = {};

  ResultadoFiltro filtrar(List<SugerenciaReemplazo> sugerencias) {
    final aceptadas = <SugerenciaReemplazo>[];
    final descartadas = <SugerenciaDescartada>[];
    for (final s in sugerencias) {
      final choque = _buscarChoque(s.nombre);
      if (choque == null) {
        aceptadas.add(s);
      } else {
        descartadas.add(
          SugerenciaDescartada(
            nombre: s.nombre,
            terminoEncontrado: base.etiquetaDe(choque.key),
            grupoAlergeno: base.grupo(choque.value)?.nombre ?? choque.value,
          ),
        );
      }
    }
    return ResultadoFiltro(aceptadas: aceptadas, descartadas: descartadas);
  }

  MapEntry<String, String>? _buscarChoque(String nombre) {
    final texto =
        ' ${_normalizador.normalizarTexto(nombre).replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')} '
            .replaceAll(RegExp(r'\s+'), ' ');

    // 1. Algún término restringido aparece como palabra (con plural tolerado).
    for (final e in _terminos.entries) {
      final patron = RegExp(' ${RegExp.escape(e.key)}(s|es)? ');
      if (patron.hasMatch(texto)) return e;
    }

    // 2. El nombre completo matchea (exacto o difuso) un ingrediente restringido.
    final items = _normalizador.separarIngredientes(nombre);
    for (final item in items) {
      final r = _emparejador.match(item);
      if (r is Coincidencia) {
        final grupoId = r.ingrediente.grupoAlergenoId;
        if (grupoId != null && _terminos.containsValue(grupoId)) {
          return MapEntry(r.ingrediente.nombreNormalizado, grupoId);
        }
      }
    }
    return null;
  }
}
