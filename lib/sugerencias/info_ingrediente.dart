import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../modelo/semaforo.dart';
import 'cliente_gemini.dart';

/// "Más info" de un ingrediente por IA (CLAUDE.md, sección 5.7).
///
/// La IA solo redacta una explicación (regla 1.1): qué es el ingrediente, de
/// dónde suele salir y en qué productos aparece. Lo que la base determinó
/// (choca, no choca, no reconocido) se le pasa como dato fijo y la respuesta
/// nunca lo cambia: el color del ingrediente sale siempre de la base.
class SolicitudInfoIngrediente {
  const SolicitudInfoIngrediente({
    required this.ingrediente,
    required this.estado,
    required this.restriccionesPerfil,
    this.chocaCon,
  });

  final String ingrediente;

  /// Lo que determinó la base local. La IA no puede contradecirlo.
  final EstadoIngrediente estado;

  /// Grupos que restringe el perfil ("leche", "cereales con gluten").
  final List<String> restriccionesPerfil;

  /// En [EstadoIngrediente.choca]: con qué grupo choca, según la base.
  final String? chocaCon;

  /// Clave de caché: la misma pregunta no se repite en la sesión.
  String get clave =>
      '$ingrediente|${estado.name}|${chocaCon ?? ''}|'
      '${restriccionesPerfil.join(',')}';
}

class InfoIngrediente {
  const InfoIngrediente({
    required this.queEs,
    required this.origen,
    required this.dondeAparece,
  });

  final String queEs;
  final String origen;
  final String dondeAparece;

  bool get vacia => queEs.isEmpty && origen.isEmpty && dondeAparece.isEmpty;
}

class ErrorInfoIngrediente implements Exception {
  const ErrorInfoIngrediente(this.motivo);
  final String motivo;

  bool get sinConexion => motivo.startsWith('sin conexión');

  @override
  String toString() => 'ErrorInfoIngrediente: $motivo';
}

abstract class ServicioInfoIngrediente {
  Future<InfoIngrediente> explicar(SolicitudInfoIngrediente solicitud);
}

class ServicioInfoIngredienteGemini implements ServicioInfoIngrediente {
  ServicioInfoIngredienteGemini({
    required String apiKey,
    String modelo = ClienteGemini.modeloDeCompilacion,
    http.Client? cliente,
  }) : _gemini = ClienteGemini(
         apiKey: apiKey,
         modelo: modelo,
         cliente: cliente,
         crearError: ErrorInfoIngrediente.new,
       );

  final ClienteGemini _gemini;

  static const _sistema =
      'Sos un asistente de una app argentina que lee etiquetas de alimentos. '
      'Explicás un ingrediente a una persona común, sin tecnicismos.\n'
      '\n'
      'Reglas:\n'
      '- Contá qué es el ingrediente, de dónde se obtiene habitualmente y en '
      'qué productos suele aparecer. Frases cortas, español rioplatense.\n'
      '- La app ya determinó, con su base de datos, si el ingrediente choca '
      'con las restricciones de la persona. Ese dato es definitivo: nunca lo '
      'contradigas ni lo pongas en duda.\n'
      '- Nunca digas que algo es apto, seguro, libre de un alérgeno o que se '
      'puede consumir. No des recomendaciones de consumo ni consejos médicos.\n'
      '- Si no conocés el ingrediente, decilo en vez de inventar.\n'
      '- Nunca nombres marcas.';

  static const _esquema = {
    'type': 'OBJECT',
    'properties': {
      'que_es': {
        'type': 'STRING',
        'description': 'Qué es el ingrediente, en una o dos frases.',
      },
      'origen': {
        'type': 'STRING',
        'description': 'De dónde se obtiene habitualmente.',
      },
      'donde_aparece': {
        'type': 'STRING',
        'description': 'En qué tipo de productos suele aparecer.',
      },
    },
    'required': ['que_es', 'origen', 'donde_aparece'],
  };

  @visibleForTesting
  static Map<String, dynamic> construirCuerpo(SolicitudInfoIngrediente s) {
    final determinacion = switch (s.estado) {
      EstadoIngrediente.choca =>
        'La base de la app determinó que CHOCA con: ${s.chocaCon}.',
      EstadoIngrediente.noChoca =>
        'La base de la app lo reconoce y no lo relaciona con las '
            'restricciones de la persona.',
      EstadoIngrediente.noReconocido =>
        'La base de la app NO reconoce este ingrediente: no se pudo '
            'verificar.',
    };
    final mensaje = StringBuffer()
      ..writeln('Ingrediente: ${s.ingrediente}')
      ..writeln(
        'Restricciones de la persona: ${s.restriccionesPerfil.join(', ')}',
      )
      ..writeln(determinacion);
    return ClienteGemini.construirCuerpo(
      sistema: _sistema,
      mensaje: mensaje.toString(),
      esquema: _esquema,
    );
  }

  @visibleForTesting
  static InfoIngrediente desdeDatos(Map<String, dynamic> datos) =>
      FiltroInfoIngrediente.limpiar(
        InfoIngrediente(
          queEs: (datos['que_es'] as String? ?? '').trim(),
          origen: (datos['origen'] as String? ?? '').trim(),
          dondeAparece: (datos['donde_aparece'] as String? ?? '').trim(),
        ),
      );

  @override
  Future<InfoIngrediente> explicar(SolicitudInfoIngrediente solicitud) async {
    final info = desdeDatos(await _gemini.generar(construirCuerpo(solicitud)));
    if (info.vacia) {
      throw const ErrorInfoIngrediente('la respuesta no tenía información');
    }
    return info;
  }
}

/// Red de seguridad determinista: saca las frases que emitan un veredicto de
/// consumo o afirmen la ausencia de un alérgeno, aunque el prompt lo prohíba.
/// Así la IA nunca puede contradecir al semáforo, que sale de la base.
class FiltroInfoIngrediente {
  static final _prohibido = RegExp(
    r'\b(apt[oa]s?|segur[oa]s?|inocuo|sin riesgo|libre de|libres de|'
    r'no contiene|sin gluten|sin tacc|sin lactosa|'
    // Cualquier forma del verbo: "consumirlo", "comerla", "tomarlos".
    r'(pod[eé]s|puede[sn]?|se puede|podr[ií]a[sn]?) (consumir|comer|tomar)\w*)'
    r'\b',
    caseSensitive: false,
  );

  static String _limpiarTexto(String texto) {
    final frases = texto.split(RegExp(r'(?<=[.!?])\s+'));
    return frases.where((f) => !_prohibido.hasMatch(f)).join(' ').trim();
  }

  static InfoIngrediente limpiar(InfoIngrediente info) => InfoIngrediente(
    queEs: _limpiarTexto(info.queEs),
    origen: _limpiarTexto(info.origen),
    dondeAparece: _limpiarTexto(info.dondeAparece),
  );
}

/// Pide la info solo cuando la persona toca "Más info" y la recuerda mientras
/// dura la sesión. Nada se guarda en la base de conocimiento (regla 1.6).
class GestorInfoIngredientes {
  GestorInfoIngredientes(this.servicio);

  /// Con la clave inyectada en la compilación; sin clave, [servicio] es
  /// `null` y la hoja avisa que la función no está configurada.
  factory GestorInfoIngredientes.desdeConfiguracion() {
    const clave = ClienteGemini.apiKeyDeCompilacion;
    return GestorInfoIngredientes(
      clave.isEmpty ? null : ServicioInfoIngredienteGemini(apiKey: clave),
    );
  }

  final ServicioInfoIngrediente? servicio;
  final _cache = <String, Future<InfoIngrediente>>{};

  bool get configurado => servicio != null;

  Future<InfoIngrediente> obtener(SolicitudInfoIngrediente solicitud) {
    final s = servicio;
    if (s == null) {
      return Future.error(
        const ErrorInfoIngrediente('falta configurar la clave'),
      );
    }
    return _cache.putIfAbsent(solicitud.clave, () {
      final futuro = s.explicar(solicitud);
      // Si falla, se olvida: tocar "Reintentar" vuelve a preguntar.
      futuro.catchError((Object _) {
        _cache.remove(solicitud.clave);
        return const InfoIngrediente(queEs: '', origen: '', dondeAparece: '');
      });
      return futuro;
    });
  }
}
