/// Un grupo de alérgeno tal como lo trata la normativa argentina.
///
/// Regla 5.3 del proyecto: en las etiquetas argentinas los cereales con gluten
/// se declaran como "trigo, avena, cebada y/o centeno", nunca como "gluten".
/// Por eso [textoEtiqueta] guarda la redacción real que aparece en el envase.
class GrupoAlergeno {
  const GrupoAlergeno({
    required this.id,
    required this.nombre,
    required this.caaObligatorio,
    required this.textoEtiqueta,
  });

  /// Identificador estable, en minúsculas y sin acentos: `leche`, `trigo`, `mani`.
  final String id;

  /// Nombre para mostrar al usuario: "leche", "trigo", "maní".
  final String nombre;

  /// `true` si el Art. 235 séptimo del CAA obliga a declararlo.
  final bool caaObligatorio;

  /// Cómo aparece redactado en una etiqueta argentina. Para los cereales con
  /// gluten es la fórmula completa "trigo, avena, cebada y/o centeno".
  final String textoEtiqueta;

  factory GrupoAlergeno.desdeJson(Map<String, dynamic> json) {
    return GrupoAlergeno(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      caaObligatorio: json['caa_obligatorio'] as bool? ?? false,
      textoEtiqueta:
          json['texto_etiqueta'] as String? ?? json['nombre'] as String,
    );
  }

  @override
  String toString() => 'GrupoAlergeno($id)';
}
