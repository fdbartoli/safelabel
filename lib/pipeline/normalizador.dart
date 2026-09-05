/// Paso 4 del Flujo B: normalización del texto que devolvió el OCR.
///
/// Requisitos (sección 5.2 del CLAUDE.md):
///  - minúsculas, quitar acentos
///  - separar por comas, punto y coma y saltos de línea
///  - resolver anidados: `chocolate (leche, lecitina de soja)` → tres ítems,
///    con el padre registrado
///  - detectar números INS y mapearlos
///  - descartar el bloque de tabla nutricional si entró en la captura
///
/// Todo determinista: se testea con casos fijos de entrada y salida esperada.
library;

/// Un ingrediente ya separado y normalizado, listo para el matcher.
class ItemNormalizado {
  const ItemNormalizado({
    required this.textoOriginal,
    required this.textoNormalizado,
    this.padre,
    this.ins,
  });

  /// Fragmento tal como salió del texto crudo (ya en minúsculas y sin acentos).
  final String textoOriginal;

  /// Texto listo para comparar contra la base.
  final String textoNormalizado;

  /// Si vino de un anidado, el nombre normalizado del ingrediente contenedor.
  /// Ej.: en `chocolate (leche)`, el ítem `leche` lleva `padre = 'chocolate'`.
  final String? padre;

  /// Código INS detectado, en forma canónica `ins 471`. `null` si no aplica.
  final String? ins;

  @override
  String toString() =>
      'ItemNormalizado($textoNormalizado${padre != null ? ', padre=$padre' : ''}'
      '${ins != null ? ', $ins' : ''})';
}

class Normalizador {
  const Normalizador();

  static const Map<String, String> _acentos = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  /// Frases que marcan el comienzo del bloque de tabla nutricional. A partir de
  /// la primera aparición se descarta el resto del texto.
  static final List<RegExp> _marcadoresTablaNutricional = [
    RegExp(r'informacion nutricional'),
    RegExp(r'valor(?:es)? energetico'),
    RegExp(r'porcion(?:es)? por envase'),
    RegExp(r'cantidad(?:es)? por porcion'),
    RegExp(r'no aporta cantidades? significativas?'),
  ];

  /// Frases que marcan el comienzo del bloque de declaración de alérgenos. La
  /// normalización de la lista de ingredientes corta acá —incluso si aparece a
  /// mitad de línea— y ese bloque lo lee [verificacion_cruzada].
  static final RegExp _marcadorContiene = RegExp(
    r'\bcontiene\b|\bpuede\s+contener\b|\belaborado\s+en\b|'
    r'\b(?:este\s+producto\s+)?se\s+(?:elabora|procesa)\s+en\b',
  );

  /// INS o número E: `ins 471`, `ins471`, `e 471`, `e471`, `471`, `160a`.
  static final RegExp _regexIns =
      RegExp(r'^(?:ins|e)?\s*([0-9]{3,4}[a-z]?(?:\([a-z0-9]+\))?)$');

  /// minúsculas + sin acentos + espacios colapsados. Para nombres sueltos.
  String normalizarTexto(String entrada) {
    final buffer = StringBuffer();
    for (final rune in entrada.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_acentos[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Pipeline completo: de texto crudo del OCR a lista de [ItemNormalizado].
  List<ItemNormalizado> separarIngredientes(String textoCrudo) {
    // 1. minúsculas + sin acentos, conservando saltos de línea.
    final sinAcentos = _quitarAcentos(textoCrudo.toLowerCase());

    // 2. recortar tabla nutricional y bloque CONTIENE.
    final soloIngredientes = _recortarBloques(sinAcentos);

    // 3. quitar un encabezado tipo "ingredientes:" si está.
    final cuerpo = soloIngredientes.replaceFirst(
      RegExp(r'^[\s\S]*?ingredientes?\s*:\s*', caseSensitive: false),
      '',
    );

    // 4. parsear respetando paréntesis.
    final items = <ItemNormalizado>[];
    _parsear(cuerpo, null, items);
    return items;
  }

  String _quitarAcentos(String entrada) {
    final buffer = StringBuffer();
    for (final rune in entrada.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_acentos[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Devuelve solo la porción de texto que corresponde a la lista de
  /// ingredientes, cortando en el primer marcador de tabla nutricional o de
  /// declaración de alérgenos, aunque aparezca a mitad de una línea. No corta en
  /// "no contiene ...".
  String _recortarBloques(String texto) {
    final lineas = texto.split('\n');
    final conservadas = <String>[];
    for (final linea in lineas) {
      final l = linea.trim();

      if (_marcadoresTablaNutricional.any((r) => r.hasMatch(l))) break;

      final m = _marcadorContiene.firstMatch(l);
      if (m != null) {
        final antes = l.substring(0, m.start);
        final esNoContiene = RegExp(r'\bno\s*$').hasMatch(antes);
        if (esNoContiene) continue; // "no contiene ..." no aporta ingredientes
        if (antes.trim().isNotEmpty) conservadas.add(antes);
        break;
      }

      conservadas.add(linea);
    }
    return conservadas.join('\n');
  }

  /// Parser recursivo. Separa por `,` `;` y saltos de línea a nivel de
  /// paréntesis 0; para cada segmento con forma `nombre (contenido)` emite el
  /// nombre y recurre en el contenido marcando el padre.
  void _parsear(String texto, String? padre, List<ItemNormalizado> acc) {
    for (final segmento in _dividirNivel0(texto)) {
      final seg = segmento.trim();
      if (seg.isEmpty) continue;

      final apertura = seg.indexOf('(');
      if (apertura == -1) {
        _emitir(seg, padre, acc);
        continue;
      }

      final cierre = _indiceCierre(seg, apertura);
      final nombre = seg.substring(0, apertura).trim();
      final contenido = cierre == -1
          ? seg.substring(apertura + 1).trim()
          : seg.substring(apertura + 1, cierre).trim();
      final resto = cierre == -1 || cierre + 1 >= seg.length
          ? ''
          : seg.substring(cierre + 1).trim();

      if (nombre.isNotEmpty) {
        _emitir(nombre, padre, acc);
      }
      final nombreNorm = nombre.isNotEmpty
          ? _limpiar(nombre)
          : padre;
      if (contenido.isNotEmpty) {
        _parsear(contenido, nombreNorm, acc);
      }
      if (resto.isNotEmpty) {
        _parsear(resto, padre, acc);
      }
    }
  }

  void _emitir(String bruto, String? padre, List<ItemNormalizado> acc) {
    final limpio = _limpiar(bruto);
    if (limpio.isEmpty) return;
    final ins = _detectarIns(limpio);
    acc.add(ItemNormalizado(
      textoOriginal: bruto.replaceAll(RegExp(r'\s+'), ' ').trim(),
      textoNormalizado: ins ?? limpio,
      padre: padre,
      ins: ins,
    ));
  }

  /// Colapsa espacios, quita signos de puntuación de borde y descarta un
  /// prefijo de categoría tipo "colorante:", "estabilizante:".
  String _limpiar(String entrada) {
    var s = entrada.replaceAll(RegExp(r'\s+'), ' ').trim();
    final m = RegExp(r'^([a-z ]{1,24}):\s*(.+)$').firstMatch(s);
    if (m != null && m.group(2)!.trim().length >= 3) {
      s = m.group(2)!.trim();
    }
    s = s.replaceAll(RegExp(r'^[\s.,;·*-]+'), '');
    s = s.replaceAll(RegExp(r'[\s.,;·*-]+$'), '');
    return s.trim();
  }

  /// Detecta un código de aditivo y lo devuelve como `ins NNN`.
  ///
  /// Acepta el texto entero como código (`ins 322`, `e471`, `322`, `150d`) o un
  /// código con prefijo `ins`/`e` embebido en un texto más largo
  /// (`emulsionante ins 322`). Un número suelto dentro de una frase no se toma,
  /// para no confundir cantidades.
  String? _detectarIns(String texto) {
    final entero = _regexIns.firstMatch(texto);
    if (entero != null) return 'ins ${entero.group(1)}';

    final embebido =
        RegExp(r'\b(?:ins|e)\s*[- ]?\s*([0-9]{3,4}[a-z]?)\b').firstMatch(texto);
    if (embebido != null) return 'ins ${embebido.group(1)}';

    return null;
  }

  /// Divide `texto` por `,` `;` y `\n` que estén fuera de todo paréntesis.
  List<String> _dividirNivel0(String texto) {
    final partes = <String>[];
    final actual = StringBuffer();
    var profundidad = 0;
    for (var i = 0; i < texto.length; i++) {
      final c = texto[i];
      if (c == '(' || c == '[') {
        profundidad++;
        actual.write(c);
      } else if (c == ')' || c == ']') {
        if (profundidad > 0) profundidad--;
        actual.write(c);
      } else if (profundidad == 0 && (c == ',' || c == ';' || c == '\n')) {
        partes.add(actual.toString());
        actual.clear();
      } else {
        actual.write(c);
      }
    }
    if (actual.isNotEmpty) partes.add(actual.toString());
    return partes;
  }

  /// Índice del `)` que cierra el `(` que está en [apertura]. -1 si no cierra.
  int _indiceCierre(String texto, int apertura) {
    var profundidad = 0;
    for (var i = apertura; i < texto.length; i++) {
      final c = texto[i];
      if (c == '(' || c == '[') profundidad++;
      if (c == ')' || c == ']') {
        profundidad--;
        if (profundidad == 0) return i;
      }
    }
    return -1;
  }
}
