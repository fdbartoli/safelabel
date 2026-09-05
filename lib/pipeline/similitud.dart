/// Medidas de similitud entre cadenas, para el match difuso (paso 5).
///
/// El OCR devuelve "caselnato de sodlo" por "caseinato de sodio": comparar por
/// igualdad de strings no alcanza (antipatrón, sección 8).
library;

/// Distancia de Levenshtein clásica (inserción/borrado/sustitución = 1).
int distanciaLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var fila = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    var anterior = fila[0];
    fila[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final temp = fila[j];
      final costo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      fila[j] = [
        fila[j] + 1, // borrado
        fila[j - 1] + 1, // inserción
        anterior + costo, // sustitución
      ].reduce((x, y) => x < y ? x : y);
      anterior = temp;
    }
  }
  return fila[b.length];
}

/// Similitud por Levenshtein normalizada a [0, 1]. 1 = idénticas.
double ratioLevenshtein(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1;
  return 1 - distanciaLevenshtein(a, b) / maxLen;
}

/// Coeficiente de Sørensen–Dice sobre bigramas. Bueno para reordenamientos y
/// palabras de más ("lecitina soja" vs "lecitina de soja").
double coeficienteDice(String a, String b) {
  if (a == b) return 1;
  if (a.length < 2 || b.length < 2) return 0;

  final bigramasA = _bigramas(a);
  final bigramasB = _bigramas(b);

  var interseccion = 0;
  final usados = List<bool>.filled(bigramasB.length, false);
  for (final bg in bigramasA) {
    for (var i = 0; i < bigramasB.length; i++) {
      if (!usados[i] && bigramasB[i] == bg) {
        usados[i] = true;
        interseccion++;
        break;
      }
    }
  }
  return 2 * interseccion / (bigramasA.length + bigramasB.length);
}

List<String> _bigramas(String s) {
  final limpio = s.replaceAll(' ', '');
  return [for (var i = 0; i < limpio.length - 1; i++) limpio.substring(i, i + 2)];
}

/// Similitud combinada usada por el matcher: el mayor entre Dice y Levenshtein.
/// Dice capta palabras de más; Levenshtein capta typos de OCR letra a letra.
double similitud(String a, String b) {
  final d = coeficienteDice(a, b);
  final l = ratioLevenshtein(a, b);
  return d > l ? d : l;
}
