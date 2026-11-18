/// Semáforo por perfil: arriba del resultado, una tarjeta por cada perfil
/// activo que dice de un vistazo si esa persona puede consumir el producto,
/// y el detalle de los ingredientes en rojo o verde para ese perfil. Los tres
/// bloques (sección 5.5) siguen en "Ver análisis completo".
///
/// Excepción a la regla 1.4 pedida para el proyecto (2026-11-10). El verde
/// tiene condiciones: solo se enciende cuando la app pudo verificar TODA la
/// etiqueta para ese perfil. Si quedó algo sin verificar, el perfil queda en
/// ámbar, nunca en verde, porque "no encontrado" no significa "seguro"
/// (regla 1.3, que sigue vigente).
///
/// Los textos son para la persona, no técnicos: frases con el nombre de pila,
/// qué se encontró y, en ámbar, qué hacer.
library;

enum ColorSemaforo {
  /// Una o más restricciones del perfil coinciden con la etiqueta.
  rojo,

  /// Sin coincidencias, pero algo impidió verificar la etiqueta completa.
  ambar,

  /// Todo verificado y nada choca con el perfil.
  verde,
}

/// Estado de un ingrediente para un perfil concreto.
enum EstadoIngrediente {
  /// Choca con una restricción del perfil.
  choca,

  /// Está en la base y no choca con el perfil.
  noChoca,

  /// No está en la base: no se puede afirmar que no choque (regla 1.3).
  noReconocido,
}

class IngredienteSemaforo {
  const IngredienteSemaforo({
    required this.texto,
    required this.estado,
    this.motivo,
    this.declarado = false,
  });

  /// Nombre del ingrediente como se leyó en la etiqueta.
  final String texto;
  final EstadoIngrediente estado;

  /// En [EstadoIngrediente.choca]: qué contiene ("cereales con gluten").
  final String? motivo;

  /// `true` si no sale de la lista sino de la línea "CONTIENE" de la etiqueta.
  final bool declarado;
}

class SemaforoPerfil {
  const SemaforoPerfil({
    required this.perfil,
    required this.color,
    required this.motivos,
    required this.ingredientes,
    this.restricciones = const [],
    this.avatar = '',
  });

  /// Semilla del avatar del perfil (ver `ui/avatar.dart`).
  final String avatar;

  /// Nombre completo del perfil ("Sofía (alergia a la leche)").
  final String perfil;

  /// Nombres de los grupos que restringe el perfil ("leche").
  final List<String> restricciones;
  final ColorSemaforo color;

  /// Explicación corta debajo del titular: qué se encontró o qué hacer.
  final List<String> motivos;

  /// Ingredientes de la etiqueta, en orden, con su estado para este perfil.
  final List<IngredienteSemaforo> ingredientes;

  /// El nombre de pila, para las frases: "Sofía (alergia a la leche)" →
  /// "Sofía".
  String get nombre => nombreCorto(perfil);

  static String nombreCorto(String perfil) {
    final corte = perfil.indexOf('(');
    final base = (corte > 0 ? perfil.substring(0, corte) : perfil).trim();
    return base.isEmpty ? perfil.trim() : base;
  }

  /// La frase principal de la tarjeta.
  String get titular => switch (color) {
    ColorSemaforo.verde => '$nombre puede consumir este producto',
    ColorSemaforo.rojo => 'No es seguro para $nombre',
    ColorSemaforo.ambar => 'Revisalo antes de que $nombre lo consuma',
  };

  /// Decide el color de un perfil y arma la explicación.
  ///
  /// [choques]: ingredientes que chocan con el perfil. [noReconocidos]:
  /// nombres de los ingredientes que la base no tiene. [trazas]: grupos del
  /// perfil que la etiqueta menciona en "PUEDE CONTENER". [sinCobertura]:
  /// grupos del perfil que la base todavía no detecta.
  static (ColorSemaforo, List<String>) decidir({
    required String perfil,
    required List<IngredienteSemaforo> choques,
    required List<String> noReconocidos,
    required int noLegibles,
    required int totalItems,
    List<String> trazas = const [],
    List<String> sinCobertura = const [],
  }) {
    final nombre = nombreCorto(perfil);

    if (choques.isNotEmpty) {
      final deLaLista = [
        for (final c in choques)
          if (!c.declarado)
            c.motivo == null ? c.texto : '${c.texto} (${c.motivo})',
      ];
      final declarados = [
        for (final c in choques)
          if (c.declarado && c.motivo != null) c.motivo!,
      ];
      return (
        ColorSemaforo.rojo,
        [
          if (deLaLista.isNotEmpty) 'Contiene ${_enumerar(deLaLista)}.',
          if (declarados.isNotEmpty)
            'La etiqueta declara que contiene ${_enumerar(declarados)}.',
        ],
      );
    }

    final faltantes = <String>[
      if (totalItems == 0)
        'No pudimos leer la lista de ingredientes. Probá con otra foto.',
      if (noReconocidos.isNotEmpty)
        noReconocidos.length == 1
            ? 'No reconocimos "${noReconocidos.single}". Fijate en la '
                  'etiqueta si es un problema para $nombre.'
            : 'No reconocimos ${_enumerar([for (final n in noReconocidos) '"$n"'])}. '
                  'Fijate en la etiqueta si son un problema para $nombre.',
      if (noLegibles > 0)
        'Una parte de la etiqueta no se leyó bien. Probá con otra foto.',
      if (trazas.isNotEmpty)
        'La etiqueta avisa que puede contener ${_enumerar(trazas)}.',
      if (sinCobertura.isNotEmpty)
        'Todavía no sabemos detectar ${_enumerar(sinCobertura)}.',
    ];
    if (faltantes.isNotEmpty) return (ColorSemaforo.ambar, faltantes);

    return (
      ColorSemaforo.verde,
      [
        totalItems == 1
            ? 'Revisamos el ingrediente y no es un problema para $nombre.'
            : 'Revisamos los $totalItems ingredientes y ninguno es un '
                  'problema para $nombre.',
      ],
    );
  }

  /// "a", "a y b", "a, b y c", "a, b, c y 2 más".
  static String _enumerar(List<String> items, {int maximo = 3}) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    if (items.length > maximo) {
      final resto = items.length - maximo;
      return '${items.take(maximo).join(', ')} y $resto más';
    }
    return '${items.take(items.length - 1).join(', ')} y ${items.last}';
  }
}
