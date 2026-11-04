/// Paso 4 del Flujo B: normalización del texto que devolvió el OCR.
///
/// Requisitos (sección 5.2 del CLAUDE.md):
///  - minúsculas, quitar acentos
///  - separar por comas y punto y coma; los saltos de línea separan solo si
///    no son un corte de renglón a mitad de ingrediente ([unirRenglones])
///  - descartar lo anterior al encabezado "ingredientes" y quitar cantidades
///    ("30 mg/kg") y referencias legales ("Ley N° 25.630")
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
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
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
  static final RegExp _regexIns = RegExp(
    r'^(?:ins|e)?\s*([0-9]{3,4}[a-z]?(?:\([a-z0-9]+\))?)$',
  );

  /// minúsculas + sin acentos + espacios colapsados. Para nombres sueltos.
  String normalizarTexto(String entrada) {
    final buffer = StringBuffer();
    for (final rune in entrada.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_acentos[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Pipeline completo: de texto crudo del OCR a lista de [ItemNormalizado].
  List<ItemNormalizado> separarIngredientes(String textoCrudo) {
    // 1. unir los renglones que el envase cortó a mitad de un ingrediente.
    final unido = unirRenglones(textoCrudo);

    // 2. minúsculas + sin acentos, conservando saltos de línea.
    final sinAcentos = _quitarAcentos(unido.toLowerCase());

    // 3. descartar lo anterior al encabezado "ingredientes" (texto
    //    publicitario, marca), si el encabezado está.
    final desdeEncabezado = _desdeEncabezado(sinAcentos);

    // 4. recortar tabla nutricional y bloque CONTIENE.
    final cuerpo = _recortarBloques(desdeEncabezado);

    // 5. parsear respetando paréntesis.
    final items = <ItemNormalizado>[];
    _parsear(cuerpo, null, items);
    return items;
  }

  /// Une los renglones que el envase cortó por falta de espacio: la lista de
  /// ingredientes es un párrafo, y un salto de línea casi nunca separa
  /// ingredientes. Se une cuando:
  ///  - el renglón anterior no termina en `,` ni `;` (que ya separan), y
  ///  - el siguiente arranca en minúscula, dígito o paréntesis, o el corte
  ///    cae dentro de un paréntesis abierto, o el anterior termina en guion.
  /// Un renglón que arranca en mayúscula después de uno cerrado se respeta:
  /// algunas etiquetas ponen un ingrediente por renglón.
  String unirRenglones(String texto) {
    final renglones = texto.split('\n');
    if (renglones.length < 2) return texto;
    final b = StringBuffer(renglones.first);
    var profundidad = _balance(renglones.first);
    for (var i = 1; i < renglones.length; i++) {
      final anterior = b.toString().trimRight();
      final siguiente = renglones[i].trimLeft();
      final finAnterior = anterior.isEmpty ? '' : anterior[anterior.length - 1];
      final inicio = siguiente.isEmpty ? '' : siguiente[0];
      final unir = siguiente.isNotEmpty &&
          finAnterior != ',' &&
          finAnterior != ';' &&
          (profundidad > 0 ||
              finAnterior == '-' ||
              RegExp(r'[a-zà-ÿ0-9(\[)\]]').hasMatch(inicio));
      if (unir && finAnterior == '-') {
        // palabra cortada con guion: "vege-" + "tal" → "vegetal"
        final sinGuion = anterior.substring(0, anterior.length - 1);
        b
          ..clear()
          ..write(sinGuion)
          ..write(siguiente);
      } else if (unir) {
        b
          ..clear()
          ..write(anterior)
          ..write(' ')
          ..write(siguiente);
      } else {
        b
          ..write('\n')
          ..write(renglones[i]);
      }
      profundidad += _balance(renglones[i]);
      if (profundidad < 0) profundidad = 0;
    }
    return b.toString();
  }

  int _balance(String s) {
    var n = 0;
    for (final c in s.split('')) {
      if (c == '(' || c == '[') n++;
      if (c == ')' || c == ']') n--;
    }
    return n;
  }

  /// Si aparece el encabezado de la lista ("ingredientes:", "ingredientes;",
  /// o "ingredientes" al comienzo de un renglón), descarta todo lo anterior.
  String _desdeEncabezado(String texto) {
    final conSigno = RegExp(r'\bingredientes?\s*[:;]\s*').firstMatch(texto);
    if (conSigno != null) return texto.substring(conSigno.end);
    final alInicio =
        RegExp(r'(?:^|\n)\s*ingredientes?\b\s*[.\-]?\s*').firstMatch(texto);
    if (alInicio != null) return texto.substring(alInicio.end);
    return texto;
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
      final nombreNorm = nombre.isNotEmpty ? _limpiar(nombre) : padre;
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
    acc.add(
      ItemNormalizado(
        textoOriginal: bruto.replaceAll(RegExp(r'\s+'), ' ').trim(),
        textoNormalizado: ins ?? limpio,
        padre: padre,
        ins: ins,
      ),
    );
  }

  /// Cantidades de fortificación y aditivos: "30 mg/kg", "2,2 mg/100 g", "5%".
  static final RegExp _cantidad = RegExp(
    r'\b\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|ug|g|kg|ml|l|ui|%)'
    r'(?:\s*/\s*(?:kg|g|l|100\s*g|100\s*ml))?(?![a-z])',
  );

  /// Referencia legal pegada al nombre: "ley n° 25.630", "ley 25630".
  static final RegExp _ley = RegExp(r'\bley\s*(?:n\s*[°º.]?\s*)?\d[\d.]*');

  /// Aclaraciones del tipo "-como hierro-".
  static final RegExp _comoAlgo = RegExp(r'-?\s*\bcomo\s+[a-z]+\s*-?');

  /// Colapsa espacios, quita cantidades, referencias legales y puntuación de
  /// borde, y descarta un prefijo de categoría tipo "colorante:".
  String _limpiar(String entrada) {
    var s = entrada.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(_cantidad, ' ');
    s = s.replaceAll(_ley, ' ');
    s = s.replaceAll(_comoAlgo, ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // "colorante: caramelo" → "caramelo". Solo si lo que sigue es un nombre:
    // en "niacina: 13" (sin la unidad) el nombre es lo de adelante.
    final m = RegExp(r'^([a-z ]{1,24}):\s*([a-z].{2,}|\d{3,4}[a-z]?)$')
        .firstMatch(s);
    if (m != null) {
      s = m.group(2)!.trim();
    }
    s = s.replaceAll(RegExp(r'^[\s.,;:·*-]+'), '');
    s = s.replaceAll(RegExp(r'[\s.,;:·*-]+$'), '');
    // Si solo quedó un número suelto ("13", "25.630") no es un ingrediente.
    // Un código INS suelto ("322", "150d") sí lo es.
    if (RegExp(r'^[\d.,\s]+$').hasMatch(s) &&
        !RegExp(r'^\d{3,4}[a-z]?$').hasMatch(s)) {
      return '';
    }
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

    final embebido = RegExp(r'\b(?:ins|e)\s*[- ]?\s*([0-9]{3,4}[a-z]?)\b')
        .firstMatch(texto);
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
