import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelo/grupo_alergeno.dart';
import '../modelo/ingrediente.dart';
import '../pipeline/normalizador.dart';

/// La base de conocimiento local de la Etapa 1: sin backend, sin SQLite, solo
/// el JSON empaquetado como asset.
///
/// Reglas 1.1 y 1.6: los datos que entran acá vienen de fuentes citables
/// (CAA art. 235 séptimo, taxonomía de Open Food Facts, tabla INS del Codex) y
/// requieren revisión humana. Esta clase nunca determina alérgenos: solo indexa
/// y consulta lo que ya fue determinado.
class BaseConocimiento {
  BaseConocimiento._({
    required this.version,
    required this.atribucion,
    required this.grupos,
    required this.ingredientes,
    required this.excepciones,
    required this._indice,
    required this._etiquetaDeTermino,
  });

  /// Versión de la base usada en el análisis. Se registra por trazabilidad
  /// (sección 10).
  final String version;

  /// Texto de atribución obligatorio por la licencia ODbL de Open Food Facts.
  final String atribucion;

  final Map<String, GrupoAlergeno> grupos;
  final List<Ingrediente> ingredientes;
  final List<Excepcion> excepciones;

  /// nombre/sinónimo normalizado → ingrediente.
  final Map<String, Ingrediente> _indice;

  /// nombre/sinónimo normalizado → texto tal como figura en la base (para
  /// mostrar de qué término salió una coincidencia difusa).
  final Map<String, String> _etiquetaDeTermino;

  /// Todos los términos normalizados indexados (canónicos + sinónimos).
  Iterable<String> get terminosIndexados => _indice.keys;

  int get cantidadIngredientes => ingredientes.length;

  /// Ingrediente cuyo nombre canónico o sinónimo normalizado es exactamente
  /// [terminoNormalizado]. `null` si no hay match exacto.
  Ingrediente? matchExacto(String terminoNormalizado) =>
      _indice[terminoNormalizado];

  /// Cómo figura en la base el término indexado [terminoNormalizado].
  String etiquetaDe(String terminoNormalizado) =>
      _etiquetaDeTermino[terminoNormalizado] ?? terminoNormalizado;

  GrupoAlergeno? grupo(String id) => grupos[id];

  /// Excepción del CAA que aplica a [nombreNormalizado] para [grupoAlergenoId].
  Excepcion? excepcionPara(String nombreNormalizado, String grupoAlergenoId) {
    for (final e in excepciones) {
      if (e.grupoAlergenoId == grupoAlergenoId &&
          nombreNormalizado.contains(e.nombreNormalizado)) {
        return e;
      }
    }
    return null;
  }

  static const _normalizador = Normalizador();

  /// Construye la base desde el string JSON. Sin dependencias de Flutter: se usa
  /// directo en los tests.
  factory BaseConocimiento.desdeJsonString(String contenido) {
    final raw = jsonDecode(contenido) as Map<String, dynamic>;
    final normalizar = _normalizador.normalizarTexto;

    final grupos = <String, GrupoAlergeno>{};
    for (final g in (raw['grupos_alergenos'] as List<dynamic>? ?? const [])) {
      final grupo = GrupoAlergeno.desdeJson(g as Map<String, dynamic>);
      grupos[grupo.id] = grupo;
    }

    final ingredientes = <Ingrediente>[];
    final indice = <String, Ingrediente>{};
    final etiquetaDeTermino = <String, String>{};

    for (final i in (raw['ingredientes'] as List<dynamic>? ?? const [])) {
      final ing = Ingrediente.desdeJson(i as Map<String, dynamic>, normalizar);
      ingredientes.add(ing);

      void indexar(String bruto, String norm) {
        if (norm.isEmpty) return;
        indice.putIfAbsent(norm, () => ing);
        etiquetaDeTermino.putIfAbsent(norm, () => bruto);
      }

      indexar(ing.nombreCanonico, ing.nombreNormalizado);
      for (final s in ing.sinonimos) {
        indexar(s.texto, s.textoNormalizado);
      }
    }

    final excepciones = <Excepcion>[
      for (final e in (raw['excepciones'] as List<dynamic>? ?? const []))
        Excepcion.desdeJson(e as Map<String, dynamic>, normalizar),
    ];

    return BaseConocimiento._(
      version: raw['version'] as String? ?? 'sin-version',
      atribucion: raw['atribucion'] as String? ?? '',
      grupos: grupos,
      ingredientes: ingredientes,
      excepciones: excepciones,
      indice: indice,
      etiquetaDeTermino: etiquetaDeTermino,
    );
  }

  /// Carga el asset empaquetado con la app.
  static Future<BaseConocimiento> cargarDesdeAssets({
    String ruta = 'lib/datos/ingredientes.json',
  }) async {
    final contenido = await rootBundle.loadString(ruta);
    return BaseConocimiento.desdeJsonString(contenido);
  }
}
