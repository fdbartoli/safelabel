/// Paleta y tema de la app.
///
/// Dos temas, a propósito separados:
///  - `temaApp` — verde pastel moderno. Para el chrome general: inicio,
///    selección de perfiles, captura, pantalla de texto pegado.
///  - `temaResultado` — neutro, sin verde. Para la pantalla de resultado
///    exclusivamente.
///
/// Por qué separados (regla 1.4, sección 1 del CLAUDE.md): "sin semáforos
/// verdes" existe porque un falso negativo acá puede ser una reacción
/// alérgica grave, y el verde es el color que más se lee como "aprobado".
/// `ColorScheme.fromSeed` tiñe TODAS las superficies con el tono semilla
/// (fondos, bordes, tarjetas), no solo los botones — así que seedear toda la
/// app en verde filtraría ese tinte hasta la pantalla de hallazgos. La
/// pantalla de resultado se envuelve en su propio `Theme` con una semilla
/// neutra para que eso sea imposible, no solo una convención a recordar.
library;

import 'package:flutter/material.dart';

/// Verde salvia pastel: la marca. Nunca se usa para `temaResultado`.
const colorSemillaMarca = Color(0xFF74A687);

/// Gris neutro (esquema monocromático): sin connotación de aprobación y
/// combina con el verde salvia de la marca, que aparece solo en las acciones
/// (botón "Sugerir sustitutos").
const colorSemillaResultado = Color(0xFF8A8A8A);

ThemeData _construir(
  Color semilla, {
  DynamicSchemeVariant variante = DynamicSchemeVariant.tonalSpot,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: semilla,
    brightness: Brightness.light,
    dynamicSchemeVariant: variante,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: scheme.surfaceContainerHigh,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}

/// Verde pastel moderno: inicio, perfiles, captura, texto pegado.
final ThemeData temaApp = _construir(colorSemillaMarca);

/// Neutro, sin verde: exclusivo de la pantalla de resultado (regla 1.4).
final ThemeData temaResultado = _construir(
  colorSemillaResultado,
  variante: DynamicSchemeVariant.monochrome,
);
