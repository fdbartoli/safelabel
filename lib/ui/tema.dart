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

/// Tipografía de la app (ver la sección `fonts` de pubspec.yaml).
const familiaTipografica = 'PlusJakartaSans';

/// Verde salvia pastel: la marca. Nunca se usa para `temaResultado`.
const colorSemillaMarca = Color(0xFF74A687);

/// Gris neutro (esquema monocromático): sin connotación de aprobación y
/// combina con el verde salvia de la marca, que aparece solo en las acciones
/// (botón "Sugerir sustitutos").
const colorSemillaResultado = Color(0xFF8A8A8A);

ThemeData _construir(
  Color semilla, {
  DynamicSchemeVariant variante = DynamicSchemeVariant.tonalSpot,
  Brightness brillo = Brightness.light,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: semilla,
    brightness: brillo,
    dynamicSchemeVariant: variante,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Plus Jakarta Sans en toda la app (pubspec.yaml), empaquetada para que
    // funcione sin conexión.
    fontFamily: familiaTipografica,
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
        textStyle: const TextStyle(
          fontFamily: familiaTipografica,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(
          fontFamily: familiaTipografica,
          fontWeight: FontWeight.w600,
        ),
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
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}

/// Colores del semáforo por perfil (excepción a la regla 1.4, 2026-11-10).
/// Fondo claro + color fuerte para íconos y texto: contraste suficiente para
/// leerlo de un vistazo en el supermercado. Se usan solo en la sección del
/// semáforo; el resto de la pantalla de resultado sigue neutra.
class ColoresSemaforo {
  const ColoresSemaforo._(this.fondo, this.fuerte, this.texto);

  final Color fondo;
  final Color fuerte;
  final Color texto;

  static const rojo = ColoresSemaforo._(
    Color(0xFFFDE4E1),
    Color(0xFFC62828),
    Color(0xFF7F1D1D),
  );
  static const ambar = ColoresSemaforo._(
    Color(0xFFFFF1D6),
    Color(0xFFB26A00),
    Color(0xFF5C3B00),
  );
  static const verde = ColoresSemaforo._(
    Color(0xFFDDF3E3),
    Color(0xFF2E7D32),
    Color(0xFF14532D),
  );

  // Modo oscuro: fondo oscuro teñido y color claro, con el mismo contraste.
  static const rojoOscuro = ColoresSemaforo._(
    Color(0xFF3D2020),
    Color(0xFFFF8A80),
    Color(0xFFFFDAD6),
  );
  static const ambarOscuro = ColoresSemaforo._(
    Color(0xFF3A2E14),
    Color(0xFFFFC266),
    Color(0xFFFFE3B8),
  );
  static const verdeOscuro = ColoresSemaforo._(
    Color(0xFF173222),
    Color(0xFF7BD88F),
    Color(0xFFCDEFD6),
  );

  /// Rojo, ámbar o verde según el brillo del tema actual.
  static ColoresSemaforo segun(
    Brightness brillo, {
    required bool rojo,
    required bool verde,
  }) {
    final oscuro = brillo == Brightness.dark;
    if (rojo) return oscuro ? rojoOscuro : ColoresSemaforo.rojo;
    if (verde) return oscuro ? verdeOscuro : ColoresSemaforo.verde;
    return oscuro ? ambarOscuro : ambar;
  }
}

/// Verde pastel moderno: inicio, perfiles, captura, texto pegado.
final ThemeData temaApp = _construir(colorSemillaMarca);

/// La misma marca en modo oscuro.
final ThemeData temaAppOscuro = _construir(
  colorSemillaMarca,
  brillo: Brightness.dark,
);

/// Neutro, sin verde: exclusivo de la pantalla de resultado (regla 1.4).
final ThemeData temaResultado = _construir(
  colorSemillaResultado,
  variante: DynamicSchemeVariant.monochrome,
);

/// El tema neutro de resultado en modo oscuro.
final ThemeData temaResultadoOscuro = _construir(
  colorSemillaResultado,
  variante: DynamicSchemeVariant.monochrome,
  brillo: Brightness.dark,
);

/// El tema de resultado que corresponde al modo (claro u oscuro) actual.
ThemeData temaResultadoPara(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? temaResultadoOscuro
    : temaResultado;

/// Los colores de la marca (verde salvia) para el modo actual. Para las
/// acciones dentro de pantallas con tema neutro (sustitutos, "Más info").
ColorScheme marcaPara(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark ? temaAppOscuro : temaApp)
        .colorScheme;
