import '../datos/base_conocimiento.dart';
import '../modelo/ingrediente.dart';
import '../pipeline/normalizador.dart';

class EvidenciaCatalogo {
  const EvidenciaCatalogo({
    required this.fuenteId,
    required this.titulo,
    required this.url,
    required this.fragmento,
  });

  final String fuenteId;
  final String titulo;
  final String url;
  final String fragmento;
}

class RelacionRestriccion {
  const RelacionRestriccion({
    required this.restriccionId,
    required this.perfilId,
    required this.nombre,
    required this.nombreVisible,
    required this.tipo,
    required this.certeza,
    required this.evidencias,
  });

  final String restriccionId;
  final String perfilId;
  final String nombre;
  final String nombreVisible;
  final String tipo;
  final Certeza certeza;
  final List<EvidenciaCatalogo> evidencias;

  String get fuentes => evidencias.isEmpty
      ? 'Base de conocimiento local'
      : evidencias.map((e) => e.titulo).toSet().join(' · ');
}

class ConceptoConocimiento {
  const ConceptoConocimiento({
    required this.id,
    required this.nombreCanonico,
    required this.denominaciones,
    required this.relaciones,
  });

  final String id;
  final String nombreCanonico;

  /// término normalizado → denominación tal como se almacena en la base.
  final Map<String, String> denominaciones;
  final List<RelacionRestriccion> relaciones;
}

class CatalogoConocimiento {
  CatalogoConocimiento({required this.version, required this.conceptos}) {
    for (final concepto in conceptos) {
      for (final entry in concepto.denominaciones.entries) {
        _indice.putIfAbsent(entry.key, () => concepto);
        _etiquetas.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  final String version;
  final List<ConceptoConocimiento> conceptos;
  final Map<String, ConceptoConocimiento> _indice = {};
  final Map<String, String> _etiquetas = {};

  Iterable<String> get terminosIndexados => _indice.keys;

  ConceptoConocimiento? matchExacto(String terminoNormalizado) =>
      _indice[terminoNormalizado];

  String etiquetaDe(String terminoNormalizado) =>
      _etiquetas[terminoNormalizado] ?? terminoNormalizado;

  /// Compatibilidad transitoria para tests y módulos aún basados en el JSON.
  /// La aplicación productiva carga el catálogo directamente desde SQLite.
  factory CatalogoConocimiento.desdeBaseLegacy(BaseConocimiento base) {
    const normalizador = Normalizador();
    return CatalogoConocimiento(
      version: base.version,
      conceptos: [
        for (var indice = 0; indice < base.ingredientes.length; indice++)
          _desdeIngredienteLegacy(
            base.ingredientes[indice],
            indice,
            normalizador,
            base,
          ),
      ],
    );
  }

  static ConceptoConocimiento _desdeIngredienteLegacy(
    Ingrediente ingrediente,
    int indice,
    Normalizador normalizador,
    BaseConocimiento base,
  ) {
    final grupoId = ingrediente.grupoAlergenoId;
    return ConceptoConocimiento(
      id: 'LEGACY-$indice',
      nombreCanonico: ingrediente.nombreCanonico,
      denominaciones: {
        normalizador.normalizarTexto(ingrediente.nombreCanonico):
            ingrediente.nombreCanonico,
        for (final sinonimo in ingrediente.sinonimos)
          sinonimo.textoNormalizado: sinonimo.texto,
      },
      relaciones: grupoId == null
          ? const []
          : [
              RelacionRestriccion(
                restriccionId: grupoId,
                perfilId: grupoId,
                nombre: base.grupo(grupoId)?.nombre ?? grupoId,
                nombreVisible: base.grupo(grupoId)?.nombre ?? grupoId,
                tipo: 'RELATED',
                certeza: ingrediente.certeza,
                evidencias: [
                  EvidenciaCatalogo(
                    fuenteId: 'legacy',
                    titulo: ingrediente.fuente,
                    url: '',
                    fragmento: ingrediente.explicacion,
                  ),
                ],
              ),
            ],
    );
  }
}
